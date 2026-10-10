/* A pull-based, single-threaded libcurl bridge. Policy lives in Mojo. */
#include <curl/curl.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <strings.h>
#include <time.h>
#include <zlib.h>

#define MAX_DECODERS 5

typedef struct {
    z_stream stream;
    unsigned char input[CURL_MAX_WRITE_SIZE];
    int gzip, initialized, ended;
    unsigned char *probe;
    size_t probe_size;
    int probing;
} Decoder;

typedef struct Transfer Transfer;
typedef struct {
    CURLM *multi;
    Transfer *head;
    size_t refs;
    int closed;
} Pool;

struct Transfer {
    Pool *pool;
    Transfer *next;
    CURL *easy;
    struct curl_slist *request_headers;
    unsigned char *upload;
    size_t upload_size;
    char *headers;
    size_t header_size;
    unsigned char body[CURL_MAX_WRITE_SIZE];
    size_t body_size, body_offset;
    int header_ready, paused, receiving, done, error, connected;
    double connect_timeout, read_timeout, write_timeout;
    double started, last_read, last_write;
    curl_off_t downloaded, uploaded;
    Decoder decoders[MAX_DECODERS];
    int decoder_count;
};

static double now_seconds(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (double)t.tv_sec + (double)t.tv_nsec / 1e9;
}

static void release_pool(Pool *p) {
    if (--p->refs == 0) {
        curl_multi_cleanup(p->multi);
        free(p);
    }
}

static void finish(Transfer *t, int error) {
    if (t->done) return;
    t->error = error;
    t->done = 1;
    if (t->easy) {
        if (error >= 0) curl_easy_setopt(t->easy, CURLOPT_FORBID_REUSE, 1L);
        curl_multi_remove_handle(t->pool->multi, t->easy);
        curl_easy_cleanup(t->easy);
        t->easy = NULL;
    }
}

static int configure_decoders(Transfer *t) {
    char *headers = strdup(t->headers);
    if (!headers) return 3;
    char *save = NULL;
    for (char *line = strtok_r(headers, "\r\n", &save); line;
         line = strtok_r(NULL, "\r\n", &save)) {
        if (strncasecmp(line, "Content-Encoding:", 17)) continue;
        char *encoding_save = NULL;
        for (char *encoding = strtok_r(line + 17, ",", &encoding_save); encoding;
             encoding = strtok_r(NULL, ",", &encoding_save)) {
            while (*encoding == ' ' || *encoding == '\t') encoding++;
            size_t length = strlen(encoding);
            while (length && (encoding[length - 1] == ' ' || encoding[length - 1] == '\t'))
                encoding[--length] = 0;
            if (!strcasecmp(encoding, "identity")) continue;
            if (t->decoder_count == MAX_DECODERS ||
                (strcasecmp(encoding, "gzip") && strcasecmp(encoding, "deflate"))) {
                free(headers);
                return 13;
            }
            t->decoders[t->decoder_count++].gzip = !strcasecmp(encoding, "gzip");
        }
    }
    free(headers);
    for (int i = 0; i < t->decoder_count / 2; i++) {
        int j = t->decoder_count - i - 1;
        int gzip = t->decoders[i].gzip;
        t->decoders[i].gzip = t->decoders[j].gzip;
        t->decoders[j].gzip = gzip;
    }
    return -1;
}

static int map_error(CURLcode code, Transfer *t) {
    switch (code) {
    case CURLE_OK: return -1;
    case CURLE_COULDNT_RESOLVE_HOST: case CURLE_COULDNT_CONNECT: return 2;
    case CURLE_SSL_CONNECT_ERROR: case CURLE_PEER_FAILED_VERIFICATION:
    case CURLE_SSL_CACERT_BADFILE: return 5;
    case CURLE_OPERATION_TIMEDOUT: return t->connected ? 8 : 7;
    case CURLE_SEND_ERROR: return 4;
    case CURLE_BAD_CONTENT_ENCODING: return 13;
    case CURLE_RECV_ERROR: case CURLE_PARTIAL_FILE: return 3;
    default: return 6;
    }
}

static size_t on_headers(char *data, size_t size, size_t count, void *context) {
    Transfer *t = context;
    size_t n = size * count;
    if (n >= 5 && memcmp(data, "HTTP/", 5) == 0) {
        t->header_size = 0;
        t->header_ready = 0;
    }
    if (t->header_ready) return n; /* Trailers are not initial response headers. */
    if (n > 262144 || t->header_size > 262144 - n) {
        t->error = 6;
        return 0;
    }
    char *new_headers = realloc(t->headers, t->header_size + n + 1);
    if (!new_headers) { t->error = 3; return 0; }
    t->headers = new_headers;
    memcpy(t->headers + t->header_size, data, n);
    t->header_size += n;
    t->headers[t->header_size] = 0;
    if (n == 2 && data[0] == '\r' && data[1] == '\n') {
        long status = 0;
        curl_easy_getinfo(t->easy, CURLINFO_RESPONSE_CODE, &status);
        if (status >= 200) {
            t->header_ready = 1;
            t->error = configure_decoders(t);
            if (t->error >= 0) return 0;
        }
    }
    t->last_read = now_seconds();
    return n;
}

static size_t on_body(char *data, size_t size, size_t count, void *context) {
    Transfer *t = context;
    size_t n = size * count;
    if (!t->receiving || t->body_size != t->body_offset) {
        t->paused = 1;
        return CURL_WRITEFUNC_PAUSE;
    }
    if (n > sizeof(t->body)) { t->error = 3; return 0; }
    memcpy(t->body, data, n);
    t->body_offset = 0;
    t->body_size = n;
    t->last_read = now_seconds();
    return n;
}

static int on_progress(void *context, curl_off_t dt, curl_off_t dn, curl_off_t ut, curl_off_t un) {
    Transfer *t = context;
    (void)dt; (void)ut;
    double now = now_seconds();
    if (dn != t->downloaded) { t->downloaded = dn; t->last_read = now; }
    if (un != t->uploaded) { t->uploaded = un; t->last_write = now; t->last_read = now; }
    return 0;
}

static void pump(Pool *p) {
    int running;
    CURLMcode result = curl_multi_perform(p->multi, &running);
    if (result != CURLM_OK) {
        for (Transfer *t = p->head; t; t = t->next) finish(t, 6);
        return;
    }
    int remaining;
    CURLMsg *message;
    while ((message = curl_multi_info_read(p->multi, &remaining))) {
        if (message->msg == CURLMSG_DONE) {
            Transfer *t = NULL;
            curl_easy_getinfo(message->easy_handle, CURLINFO_PRIVATE, &t);
            int error = t->error >= 0 ? t->error : map_error(message->data.result, t);
            finish(t, error);
        }
    }
    double now = now_seconds();
    for (Transfer *t = p->head; t; t = t->next) {
        if (t->done || t->paused || (t->header_ready && !t->receiving)) continue;
        double pretransfer = 0;
        curl_easy_getinfo(t->easy, CURLINFO_PRETRANSFER_TIME, &pretransfer);
        if (!t->connected && pretransfer > 0) {
            t->connected = 1;
            t->last_read = t->last_write = now;
        }
        if (!t->connected) {
            if (t->connect_timeout > 0 && now - t->started >= t->connect_timeout) finish(t, 7);
        } else if ((uint64_t)t->uploaded < t->upload_size) {
            if (t->write_timeout > 0 && now - t->last_write >= t->write_timeout) finish(t, 9);
        } else if (t->read_timeout > 0 && now - t->last_read >= t->read_timeout) {
            finish(t, 8);
        }
    }
}

void *req_pool_new(void) {
    static int initialized;
    if (!initialized) {
        if (curl_global_init(CURL_GLOBAL_DEFAULT) != CURLE_OK) return NULL;
        atexit(curl_global_cleanup);
        initialized = 1;
    }
    Pool *p = calloc(1, sizeof(*p));
    if (!p) return NULL;
    p->multi = curl_multi_init();
    if (!p->multi) { free(p); return NULL; }
    p->refs = 1;
    return p;
}

void req_pool_close(void *handle) {
    Pool *p = handle;
    if (!p || p->closed) return;
    p->closed = 1;
    for (Transfer *t = p->head; t; t = t->next) finish(t, 16);
}

void req_pool_release(void *handle) { if (handle) release_pool(handle); }

void *req_transfer_new(void *handle, const char *method, const char *url,
                       const char *headers, const unsigned char *body, size_t length,
                       int has_body, double connect_timeout, double read_timeout,
                       double write_timeout, int verify, const char *ca_file) {
    Pool *p = handle;
    if (!p || p->closed) return NULL;
    Transfer *t = calloc(1, sizeof(*t));
    if (!t) return NULL;
    t->pool = p;
    p->refs++;
    t->next = p->head;
    p->head = t;
    t->error = -1;
    t->started = t->last_read = t->last_write = now_seconds();
    t->connect_timeout = connect_timeout;
    t->read_timeout = read_timeout;
    t->write_timeout = write_timeout;
    t->upload_size = length;
    t->easy = curl_easy_init();
    if (!t->easy) { finish(t, 2); return t; }
#define SET(option, value) do { if (curl_easy_setopt(t->easy, option, value) != CURLE_OK) { finish(t, 6); return t; } } while (0)
    SET(CURLOPT_URL, url);
    SET(CURLOPT_CUSTOMREQUEST, method);
    SET(CURLOPT_HTTP_VERSION, CURL_HTTP_VERSION_1_1);
    SET(CURLOPT_PROTOCOLS_STR, "http,https");
    SET(CURLOPT_FOLLOWLOCATION, 0L);
    SET(CURLOPT_PATH_AS_IS, 1L);
    SET(CURLOPT_NOSIGNAL, 1L);
    SET(CURLOPT_PROXY, "");
    SET(CURLOPT_NETRC, CURL_NETRC_IGNORED);
    SET(CURLOPT_SSL_VERIFYPEER, verify ? 1L : 0L);
    SET(CURLOPT_SSL_VERIFYHOST, verify ? 2L : 0L);
    if (ca_file && *ca_file) SET(CURLOPT_CAINFO, ca_file);
    SET(CURLOPT_ACCEPT_ENCODING, "gzip, deflate");
    SET(CURLOPT_HTTP_CONTENT_DECODING, 0L);
    long connect_ms = LONG_MAX;
    if (connect_timeout > 0 && connect_timeout < (double)LONG_MAX / 1000 - 1)
        connect_ms = (long)(connect_timeout * 1000 + 1);
    SET(CURLOPT_CONNECTTIMEOUT_MS, connect_ms);
    SET(CURLOPT_HEADERFUNCTION, on_headers);
    SET(CURLOPT_HEADERDATA, t);
    SET(CURLOPT_WRITEFUNCTION, on_body);
    SET(CURLOPT_WRITEDATA, t);
    SET(CURLOPT_NOPROGRESS, 0L);
    SET(CURLOPT_XFERINFOFUNCTION, on_progress);
    SET(CURLOPT_XFERINFODATA, t);
    SET(CURLOPT_PRIVATE, t);
    char *copy = strdup(headers);
    if (!copy) { finish(t, 4); return t; }
    char *save = NULL;
    for (char *line = strtok_r(copy, "\n", &save); line; line = strtok_r(NULL, "\n", &save)) {
        struct curl_slist *next = curl_slist_append(t->request_headers, line);
        if (!next) { free(copy); finish(t, 4); return t; }
        t->request_headers = next;
    }
    free(copy);
    struct curl_slist *next = curl_slist_append(t->request_headers, "Expect:");
    if (!next) { finish(t, 4); return t; }
    t->request_headers = next;
    SET(CURLOPT_HTTPHEADER, t->request_headers);
    if (has_body) {
        t->upload = malloc(length ? length : 1);
        if (!t->upload) { finish(t, 4); return t; }
        if (length) memcpy(t->upload, body, length);
        SET(CURLOPT_POSTFIELDS, t->upload);
        SET(CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)length);
        SET(CURLOPT_CUSTOMREQUEST, method);
    }
    if (!strcmp(method, "HEAD")) SET(CURLOPT_NOBODY, 1L);
#undef SET
    if (curl_multi_add_handle(p->multi, t->easy) != CURLM_OK) finish(t, 6);
    return t;
}

int req_transfer_headers(void *handle) {
    Transfer *t = handle;
    while (!t->header_ready && !t->done) {
        pump(t->pool);
        if (!t->header_ready && !t->done) curl_multi_poll(t->pool->multi, NULL, 0, 25, NULL);
    }
    return t->error;
}

const char *req_transfer_header_data(void *handle) { return ((Transfer *)handle)->headers; }
size_t req_transfer_header_size(void *handle) { return ((Transfer *)handle)->header_size; }

static int64_t read_wire(Transfer *t, unsigned char *buffer, size_t capacity) {
    if (t->pool->closed) return -17; /* -(ErrorKind.StreamClosed + 1) */
    t->receiving = 1;
    t->last_read = now_seconds(); /* Time spent in application code is not an I/O wait. */
    while (t->body_size == t->body_offset && !t->done) {
        t->body_size = t->body_offset = 0;
        if (t->paused) {
            t->paused = 0;
            CURLcode result = curl_easy_pause(t->easy, CURLPAUSE_CONT);
            if (result != CURLE_OK) finish(t, map_error(result, t));
        }
        pump(t->pool);
        if (t->body_size == t->body_offset && !t->done) curl_multi_poll(t->pool->multi, NULL, 0, 25, NULL);
    }
    size_t available = t->body_size - t->body_offset;
    if (available) {
        size_t n = capacity < available ? capacity : available;
        memcpy(buffer, t->body + t->body_offset, n);
        t->body_offset += n;
        t->receiving = 0;
        return (int64_t)n;
    }
    t->receiving = 0;
    return t->error >= 0 ? -(int64_t)(t->error + 1) : 0;
}

static void clear_probe(Decoder *decoder) {
    free(decoder->probe);
    decoder->probe = NULL;
    decoder->probe_size = 0;
    decoder->probing = 0;
}

static int save_probe(Decoder *decoder, const unsigned char *input, size_t size) {
    /* A raw stream with a zlib-looking prefix starts with a stored block.
       Retain at most that block's maximum size plus its five-byte header. */
    if (decoder->probe_size + size > 65540) {
        clear_probe(decoder);
        return 1;
    }
    unsigned char *probe = realloc(decoder->probe, decoder->probe_size + size);
    if (!probe) return 0;
    memcpy(probe + decoder->probe_size, input, size);
    decoder->probe = probe;
    decoder->probe_size += size;
    return 1;
}

static int retry_raw(Decoder *decoder) {
    inflateEnd(&decoder->stream);
    memset(&decoder->stream, 0, sizeof(decoder->stream));
    decoder->initialized = 0;
    if (inflateInit2(&decoder->stream, -MAX_WBITS) != Z_OK) return 0;
    decoder->initialized = 1;
    decoder->stream.next_in = decoder->probe;
    decoder->stream.avail_in = (uInt)decoder->probe_size;
    decoder->probing = 2;
    return 1;
}

static int64_t read_decoded(Transfer *t, int index, unsigned char *buffer, size_t capacity) {
    if (index < 0) return read_wire(t, buffer, capacity);
    Decoder *decoder = &t->decoders[index];
    z_stream *stream = &decoder->stream;
    if (!decoder->initialized) {
        size_t prefix_size = 0;
        while (prefix_size < 2) {
            int64_t n = read_decoded(t, index - 1, decoder->input + prefix_size, 2 - prefix_size);
            if (n < 0) return n;
            if (!n) return prefix_size ? -14 : 0;
            prefix_size += (size_t)n;
        }
        /* Decide the deflate wrapper only after both header bytes arrive. */
        unsigned int header = ((unsigned int)decoder->input[0] << 8) | decoder->input[1];
        int wrapped = (decoder->input[0] & 15) == Z_DEFLATED &&
                      (decoder->input[0] >> 4) <= 7 && header % 31 == 0;
        int window_bits = decoder->gzip ? MAX_WBITS + 16 : (wrapped ? MAX_WBITS : -MAX_WBITS);
        if (inflateInit2(stream, window_bits) != Z_OK) return -14;
        decoder->initialized = 1;
        stream->next_in = decoder->input;
        stream->avail_in = (uInt)prefix_size;
        if (!decoder->gzip && wrapped) {
            decoder->probing = 1;
            if (!save_probe(decoder, decoder->input, prefix_size)) return -4;
        }
    }
    for (;;) {
        if (decoder->ended) {
            if (!stream->avail_in) {
                int64_t n = read_decoded(t, index - 1, decoder->input, sizeof(decoder->input));
                if (n <= 0) return n;
                stream->next_in = decoder->input;
                stream->avail_in = (uInt)n;
            }
            if (!decoder->gzip || inflateReset2(stream, MAX_WBITS + 16) != Z_OK) return -14;
            decoder->ended = 0;
        }
        uInt available = stream->avail_in;
        uInt output_size = capacity > UINT_MAX ? UINT_MAX : (uInt)capacity;
        stream->next_out = buffer;
        stream->avail_out = output_size;
        int result = inflate(stream, Z_NO_FLUSH);
        if ((result == Z_DATA_ERROR || result == Z_NEED_DICT) && decoder->probing == 1) {
            if (!retry_raw(decoder)) return -14;
            continue;
        }
        if (result != Z_OK && result != Z_STREAM_END && result != Z_BUF_ERROR) return -14;
        decoder->ended = result == Z_STREAM_END;
        size_t produced = output_size - stream->avail_out;
        if (decoder->probing == 1 && (produced || decoder->ended)) clear_probe(decoder);
        if (produced) return (int64_t)produced;
        if (!stream->avail_in && !decoder->ended) {
            if (decoder->probing == 2) clear_probe(decoder);
            int64_t n = read_decoded(t, index - 1, decoder->input, sizeof(decoder->input));
            if (n < 0) return n;
            if (!n) {
                if (decoder->probing == 1 && retry_raw(decoder)) continue;
                return -14;
            }
            if (decoder->probing == 1 && !save_probe(decoder, decoder->input, (size_t)n)) return -4;
            stream->next_in = decoder->input;
            stream->avail_in = (uInt)n;
            continue;
        }
        if (!decoder->ended && stream->avail_in == available && available) return -14;
    }
}

int64_t req_transfer_read(void *handle, unsigned char *buffer, size_t capacity) {
    Transfer *t = handle;
    if (t->pool->closed) return -17;
    int64_t result = read_decoded(t, t->decoder_count - 1, buffer, capacity);
    if (result < 0) finish(t, (int)(-result - 1));
    return result;
}

void req_transfer_free(void *handle) {
    Transfer *t = handle;
    if (!t) return;
    finish(t, 16);
    Transfer **link = &t->pool->head;
    while (*link && *link != t) link = &(*link)->next;
    if (*link) *link = t->next;
    curl_slist_free_all(t->request_headers);
    for (int i = 0; i < t->decoder_count; i++) {
        if (t->decoders[i].initialized) inflateEnd(&t->decoders[i].stream);
        clear_probe(&t->decoders[i]);
    }
    free(t->upload);
    free(t->headers);
    Pool *p = t->pool;
    free(t);
    release_pool(p);
}
