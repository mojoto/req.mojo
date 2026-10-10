/* A pull-based, single-threaded libcurl bridge. Policy lives in Mojo. */
#include <curl/curl.h>
#include <limits.h>
#include <stdint.h>
#include <stdio.h>
#include <sys/stat.h>
#include <unistd.h>
#include <fcntl.h>
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

typedef struct UploadPart UploadPart;
struct UploadPart {
    UploadPart *next;
    unsigned char *bytes;
    size_t size;
    int fd;
};
typedef struct BodyUse BodyUse;
struct BodyUse { size_t refs; int used; };
typedef struct BodyDependency BodyDependency;
struct BodyDependency { BodyDependency *next; BodyUse *use; };
typedef struct {
    UploadPart *head, *tail;
    BodyUse *use;
    BodyDependency *dependencies;
    size_t size;
    int known_length, replayable;
} UploadBody;

void *req_body_new(int known_length, int replayable) {
    UploadBody *body = calloc(1, sizeof(*body));
    if (body) {
        body->known_length = known_length; body->replayable = replayable;
        if (!replayable) {
            body->use = calloc(1, sizeof(*body->use));
            if (!body->use) { free(body); return NULL; }
            body->use->refs = 1;
        }
    }
    return body;
}

static void release_body_use(BodyUse *use) { if (use && !--use->refs) free(use); }

void req_body_free(void *handle) {
    UploadBody *body = handle;
    if (!body) return;
    UploadPart *part = body->head;
    while (part) {
        UploadPart *next = part->next;
        if (part->fd >= 0) close(part->fd);
        free(part->bytes);
        free(part);
        part = next;
    }
    release_body_use(body->use);
    BodyDependency *dependency = body->dependencies;
    while (dependency) {
        BodyDependency *next = dependency->next;
        release_body_use(dependency->use);
        free(dependency);
        dependency = next;
    }
    free(body);
}

static int append_part(UploadBody *body, UploadPart *part) {
    if (part->size > (size_t)INT64_MAX - body->size) {
        if (part->fd >= 0) close(part->fd);
        free(part->bytes); free(part); return 1;
    }
    if (body->tail) body->tail->next = part;
    else body->head = part;
    body->tail = part;
    body->size += part->size;
    return -1;
}

int req_body_bytes(void *handle, const unsigned char *bytes, size_t size) {
    UploadPart *part = calloc(1, sizeof(*part));
    if (!part) return 4;
    part->fd = -1;
    part->bytes = malloc(size ? size : 1);
    if (!part->bytes) { free(part); return 4; }
    if (size) memcpy(part->bytes, bytes, size);
    part->size = size;
    return append_part(handle, part);
}

int req_body_file(void *handle, const char *path) {
    int fd = open(path, O_RDONLY | O_NONBLOCK | O_CLOEXEC);
    if (fd < 0) return 4;
    struct stat info;
    if (fstat(fd, &info) || !S_ISREG(info.st_mode) || info.st_size < 0) {
        close(fd); return 1;
    }
    UploadPart *part = calloc(1, sizeof(*part));
    if (!part) { close(fd); return 4; }
    part->fd = fd;
    part->size = (size_t)info.st_size;
    return append_part(handle, part);
}

static int add_dependency(UploadBody *body, BodyUse *use) {
    if (!use) return -1;
    BodyDependency *dependency = malloc(sizeof(*dependency));
    if (!dependency) return 4;
    dependency->use = use;
    use->refs++;
    dependency->next = body->dependencies;
    body->dependencies = dependency;
    return -1;
}

static int body_consumed(UploadBody *body) {
    if (body->use && body->use->used) return 1;
    for (BodyDependency *item = body->dependencies; item; item = item->next)
        if (item->use->used) return 1;
    return 0;
}

static void consume_body(UploadBody *body) {
    if (body->use) body->use->used = 1;
    for (BodyDependency *item = body->dependencies; item; item = item->next)
        item->use->used = 1;
}

int req_body_append(void *handle, void *source) {
    UploadBody *body = handle, *other = source;
    if (body_consumed(other)) return 18;
    int error = add_dependency(body, other->use);
    if (error >= 0) return error;
    for (BodyDependency *item = other->dependencies; item; item = item->next) {
        error = add_dependency(body, item->use);
        if (error >= 0) return error;
    }
    for (UploadPart *part = other->head; part; part = part->next) {
        if (part->fd < 0) {
            int error = req_body_bytes(body, part->bytes, part->size);
            if (error >= 0) return error;
        } else {
            UploadPart *copy = calloc(1, sizeof(*copy));
            if (!copy) return 4;
            copy->fd = dup(part->fd);
            if (copy->fd < 0) { free(copy); return 4; }
            copy->size = part->size;
            int error = append_part(body, copy);
            if (error >= 0) return error;
        }
    }
    body->known_length &= other->known_length;
    body->replayable &= other->replayable;
    return -1;
}

int64_t req_body_length(void *handle) {
    UploadBody *body = handle;
    return body->known_length ? (int64_t)body->size : -1;
}

int req_http2_supported(void) {
    const curl_version_info_data *info = curl_version_info(CURLVERSION_NOW);
    if (!info || !(info->features & CURL_VERSION_HTTP2)) return 0;
    /* Older libcurl offers HTTP/1.1 even in TLS prior-knowledge mode. */
    return info->version_num >= 0x080a00 ? 2 : 1;
}

int req_proxy_validate(const char *proxy) {
    CURLU *url = curl_url();
    if (!url) return 2;
    char *scheme = NULL, *path = NULL, *value = NULL;
    int valid = curl_url_set(url, CURLUPART_URL, proxy, 0) == CURLUE_OK &&
        curl_url_get(url, CURLUPART_SCHEME, &scheme, 0) == CURLUE_OK &&
        (!strcmp(scheme, "http") || !strcmp(scheme, "https"));
    if (curl_url_get(url, CURLUPART_PATH, &path, 0) == CURLUE_OK)
        valid &= !strcmp(path, "/");
    if (curl_url_get(url, CURLUPART_QUERY, &value, 0) == CURLUE_OK) valid = 0;
    curl_free(value); value = NULL;
    if (curl_url_get(url, CURLUPART_FRAGMENT, &value, 0) == CURLUE_OK) valid = 0;
    curl_free(value); curl_free(path); curl_free(scheme); curl_url_cleanup(url);
    return valid ? -1 : 1;
}

typedef struct Transfer Transfer;
typedef struct {
    CURLM *multi;
    Transfer *head;
    size_t refs;
    int closed;
    int http1, http2;
    size_t max_connections, max_keepalive;
    double keepalive_expiry, last_activity;
} Pool;

struct Transfer {
    Pool *pool;
    Transfer *next;
    CURL *easy;
    struct curl_slist *request_headers;
    struct curl_slist *connection_key;
    unsigned char *upload;
    size_t upload_size;
    UploadBody *upload_body;
    UploadPart *upload_part;
    size_t upload_offset;
    int body_started, upload_eof, admitted, multiplex_wait;
    double pool_timeout;
    char *headers;
    size_t header_size, header_capacity;
    unsigned char body[CURL_MAX_WRITE_SIZE];
    size_t body_size, body_offset;
    int header_ready, paused, receiving, done, error, connected;
    double connect_timeout, read_timeout, write_timeout;
    double started, last_read, last_write;
    curl_off_t downloaded, uploaded;
    Decoder *decoders;
    int decoder_count;
    int decoders_ready;
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
    t->pool->last_activity = now_seconds();
    if (t->easy) {
        /* libcurl cancels individual HTTP/2 streams and retires broken
           connections itself. FORBID_REUSE would discard healthy peers. */
        curl_multi_remove_handle(t->pool->multi, t->easy);
        curl_easy_cleanup(t->easy);
        t->easy = NULL;
    }
}

static int configure_decoders(Transfer *t) {
    int encodings[MAX_DECODERS], count = 0;
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
            if (count == MAX_DECODERS ||
                (strcasecmp(encoding, "gzip") && strcasecmp(encoding, "deflate"))) {
                free(headers);
                return 13;
            }
            encodings[count++] = !strcasecmp(encoding, "gzip");
        }
    }
    free(headers);
    if (count) {
        t->decoders = calloc((size_t)count, sizeof(*t->decoders));
        if (!t->decoders) return 3;
        t->decoder_count = count;
        for (int i = 0; i < count; i++)
            t->decoders[i].gzip = encodings[count - i - 1];
    }
    return -1;
}

static int map_error(CURLcode code, Transfer *t) {
    switch (code) {
    case CURLE_OK: return -1;
    case CURLE_COULDNT_RESOLVE_PROXY: case CURLE_COULDNT_RESOLVE_HOST: case CURLE_COULDNT_CONNECT: return 2;
    case CURLE_SSL_CONNECT_ERROR: case CURLE_PEER_FAILED_VERIFICATION:
    case CURLE_SSL_CACERT_BADFILE: return 5;
    case CURLE_OPERATION_TIMEDOUT: return t->connected ? 8 : 7;
    case CURLE_SEND_ERROR: case CURLE_READ_ERROR: case CURLE_UPLOAD_FAILED: return 4;
    case CURLE_BAD_CONTENT_ENCODING: return 13;
    case CURLE_PARTIAL_FILE: {
        /* An incomplete HTTP/2 response is a protocol failure. */
        long version = 0;
        curl_easy_getinfo(t->easy, CURLINFO_HTTP_VERSION, &version);
        return version == CURL_HTTP_VERSION_2_0 ? 6 : 3;
    }
    case CURLE_RECV_ERROR: return 3;
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
    size_t needed = t->header_size + n + 1;
    if (needed > t->header_capacity) {
        size_t capacity = t->header_capacity ? t->header_capacity : 512;
        while (capacity < needed) capacity *= 2;
        if (capacity > 262145) capacity = 262145;
        char *new_headers = realloc(t->headers, capacity);
        if (!new_headers) { t->error = 3; return 0; }
        t->headers = new_headers;
        t->header_capacity = capacity;
    }
    memcpy(t->headers + t->header_size, data, n);
    t->header_size += n;
    t->headers[t->header_size] = 0;
    if (n == 2 && data[0] == '\r' && data[1] == '\n') {
        long status = 0;
        curl_easy_getinfo(t->easy, CURLINFO_RESPONSE_CODE, &status);
        if (status >= 200) {
            long version = 0;
            curl_easy_getinfo(t->easy, CURLINFO_HTTP_VERSION, &version);
            if (!t->pool->http1 && version != CURL_HTTP_VERSION_2_0) {
                t->error = 6;
                return 0;
            }
            t->header_ready = 1;

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

static size_t on_upload(char *buffer, size_t size, size_t count, void *context) {
    Transfer *t = context;
    if (t->upload_eof) {
        /* A callback after EOF starts a new attempt. Older libcurl may omit
           the seek callback for unknown-length HTTP/2 uploads. */
        if (body_consumed(t->upload_body)) {
            t->error = 18;
            return CURL_READFUNC_ABORT;
        }
        t->upload_part = t->upload_body->head;
        t->upload_offset = 0;
        t->upload_eof = 0;
        t->uploaded = 0;
        t->last_write = t->last_read = now_seconds();
    }
    if (!t->body_started) {
        if (body_consumed(t->upload_body)) { t->error = 18; return CURL_READFUNC_ABORT; }
        consume_body(t->upload_body);
        t->body_started = 1;
    }
    size_t capacity = size * count, filled = 0;
    while (t->upload_part && filled < capacity) {
        UploadPart *part = t->upload_part;
        size_t available = part->size - t->upload_offset;
        size_t n = capacity - filled < available ? capacity - filled : available;
        if (part->fd >= 0) {
            struct stat info;
            if (fstat(part->fd, &info) || info.st_size != (off_t)part->size) {
                t->error = 4; return CURL_READFUNC_ABORT;
            }
            ssize_t got = pread(part->fd, buffer + filled, n, (off_t)t->upload_offset);
            if (got < 0 || (n && !got)) { t->error = 4; return CURL_READFUNC_ABORT; }
            n = (size_t)got;
        } else if (n) memcpy(buffer + filled, part->bytes + t->upload_offset, n);
        filled += n;
        t->upload_offset += n;
        if (t->upload_offset == part->size) {
            t->upload_part = part->next;
            t->upload_offset = 0;
        }
    }
    t->upload_eof = filled == 0;
    return filled;
}

static int on_seek(void *context, curl_off_t offset, int origin) {
    Transfer *t = context;
    if (origin != SEEK_SET || offset != 0) return CURL_SEEKFUNC_CANTSEEK;
    if (t->body_started && body_consumed(t->upload_body)) {
        t->error = 18;
        return CURL_SEEKFUNC_FAIL;
    }
    t->upload_part = t->upload_body->head;
    t->upload_offset = 0;
    t->upload_eof = 0;
    t->uploaded = 0;
    t->last_write = t->last_read = now_seconds();
    return CURL_SEEKFUNC_OK;
}

static int same_connection(Transfer *a, Transfer *b) {
#if LIBCURL_VERSION_NUM >= 0x080200
    curl_off_t first = -1, second = -1;
    if (curl_easy_getinfo(a->easy, CURLINFO_CONN_ID, &first) == CURLE_OK &&
        curl_easy_getinfo(b->easy, CURLINFO_CONN_ID, &second) == CURLE_OK &&
        first >= 0 && second >= 0) return first == second;
#endif
    /* Older libcurl exposes the TCP endpoints during active transfers.
       ACTIVESOCKET is only available after a transfer completes. */
    long local_a = 0, local_b = 0, remote_a = 0, remote_b = 0;
    char *ip_a = NULL, *ip_b = NULL;
    curl_easy_getinfo(a->easy, CURLINFO_LOCAL_PORT, &local_a);
    curl_easy_getinfo(b->easy, CURLINFO_LOCAL_PORT, &local_b);
    curl_easy_getinfo(a->easy, CURLINFO_PRIMARY_PORT, &remote_a);
    curl_easy_getinfo(b->easy, CURLINFO_PRIMARY_PORT, &remote_b);
    curl_easy_getinfo(a->easy, CURLINFO_PRIMARY_IP, &ip_a);
    curl_easy_getinfo(b->easy, CURLINFO_PRIMARY_IP, &ip_b);
    return local_a && local_a == local_b && remote_a == remote_b &&
           ip_a && ip_b && !strcmp(ip_a, ip_b);
}

static size_t active_connections(Pool *p) {
    size_t count = 0;
    for (Transfer *t = p->head; t; t = t->next) {
        if (t->done || !t->admitted) continue;
        int seen = 0;
        if (p->http2) {
            for (Transfer *other = p->head; other != t; other = other->next) {
                if (other->done || !other->admitted) continue;
                if (same_connection(other, t)) { seen = 1; break; }
            }
        }
        if (!seen) count++;
    }
    return count;
}

static int can_multiplex(Transfer *t) {
    if (!t->pool->http2 || !t->connection_key) return 0;
    for (Transfer *other = t->pool->head; other; other = other->next) {
        if (other == t || other->done || !other->admitted || !other->header_ready) continue;
        long version = 0;
        curl_easy_getinfo(other->easy, CURLINFO_HTTP_VERSION, &version);
        if (version != CURL_HTTP_VERSION_2_0) continue;
        struct curl_slist *a = t->connection_key, *b = other->connection_key;
        while (a && b && !strcmp(a->data, b->data)) { a = a->next; b = b->next; }
        if (!a && !b) return 1;
    }
    return 0;
}

static void admit_transfers(Pool *p) {
    size_t active = active_connections(p);
    for (Transfer *t = p->head; t; t = t->next) {
        if (t->done || t->admitted) continue;
        int multiplex = can_multiplex(t);
        if (p->max_connections && active >= p->max_connections && !multiplex) {
            if (t->pool_timeout > 0 && now_seconds() - t->started >= t->pool_timeout)
                finish(t, 19);
            continue;
        }
        if (!active && p->last_activity && p->keepalive_expiry >= 0 &&
            now_seconds() - p->last_activity >= p->keepalive_expiry) {
            curl_multi_cleanup(p->multi);
            p->multi = curl_multi_init();
            if (!p->multi) { finish(t, 2); return; }
        }
        if (curl_multi_setopt(p->multi, CURLMOPT_MAXCONNECTS,
                (long)(p->max_keepalive ? p->max_keepalive : 1)) != CURLM_OK ||
            curl_multi_setopt(p->multi, CURLMOPT_MAX_TOTAL_CONNECTIONS,
                (long)p->max_connections) != CURLM_OK ||
            curl_multi_setopt(p->multi, CURLMOPT_PIPELINING,
                p->http2 ? CURLPIPE_MULTIPLEX : CURLPIPE_NOTHING) != CURLM_OK ||
            curl_multi_add_handle(p->multi, t->easy) != CURLM_OK) {
            finish(t, 6); continue;
        }
        t->admitted = 1;
        t->multiplex_wait = multiplex;
        if (multiplex) curl_easy_setopt(t->easy, CURLOPT_CONNECTTIMEOUT_MS, LONG_MAX);
        t->started = t->last_read = t->last_write = now_seconds();
        if (!multiplex) active++;
    }
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
    admit_transfers(p);
    if (!p->multi) return;
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
        if (t->done || !t->admitted || t->paused || (t->header_ready && !t->receiving)) continue;
        double pretransfer = 0;
        curl_easy_getinfo(t->easy, CURLINFO_PRETRANSFER_TIME, &pretransfer);
        if (!t->connected && pretransfer > 0) {
            t->connected = 1;
            t->multiplex_wait = 0;
            t->last_read = t->last_write = now;
        }
        if (t->multiplex_wait) {
            if (t->pool_timeout > 0 && now - t->started >= t->pool_timeout) finish(t, 19);
        } else if (!t->connected) {
            if (t->connect_timeout > 0 && now - t->started >= t->connect_timeout) finish(t, 7);
        } else if ((uint64_t)t->uploaded < t->upload_size) {
            if (t->write_timeout > 0 && now - t->last_write >= t->write_timeout) finish(t, 9);
        } else if (t->read_timeout > 0 && now - t->last_read >= t->read_timeout) {
            finish(t, 8);
        }
    }
}

void *req_pool_new(size_t max_connections, size_t max_keepalive, double keepalive_expiry,
                   int http1, int http2) {
    if ((!http1 && !http2) || (http2 && !req_http2_supported()) ||
        (!http1 && req_http2_supported() < 2)) return NULL;
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
    p->http1 = http1;
    p->http2 = http2;
    p->max_connections = max_connections;
    p->max_keepalive = max_connections && max_keepalive > max_connections ? max_connections : max_keepalive;
    p->keepalive_expiry = keepalive_expiry;
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
                       double write_timeout, int verify, const char *ca_file,
                       UploadBody *upload_body, double pool_timeout,
                       const char *proxy, const char *no_proxy, const char *ca_path) {
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
    t->upload_size = upload_body ? upload_body->size : length;
    t->pool_timeout = pool_timeout;
    t->upload_body = upload_body;
    t->upload_part = upload_body ? upload_body->head : NULL;
    t->easy = curl_easy_init();
    if (!t->easy) { finish(t, 2); return t; }
#define SET(option, value) do { if (curl_easy_setopt(t->easy, option, value) != CURLE_OK) { finish(t, 6); return t; } } while (0)
    SET(CURLOPT_URL, url);
    SET(CURLOPT_CUSTOMREQUEST, method);
    SET(CURLOPT_HTTP_VERSION, (long)(p->http2 ?
        (p->http1 ? CURL_HTTP_VERSION_2TLS : CURL_HTTP_VERSION_2_PRIOR_KNOWLEDGE) :
        CURL_HTTP_VERSION_1_1));
    SET(CURLOPT_PIPEWAIT, p->http2 ? 1L : 0L);
    if (p->http2) SET(CURLOPT_SSLVERSION, (long)CURL_SSLVERSION_TLSv1_2);
    SET(CURLOPT_PROTOCOLS_STR, "http,https");
    SET(CURLOPT_FOLLOWLOCATION, 0L);
    SET(CURLOPT_PATH_AS_IS, 1L);
    SET(CURLOPT_NOSIGNAL, 1L);
    SET(CURLOPT_PROXY, proxy);
    SET(CURLOPT_NOPROXY, no_proxy);
    SET(CURLOPT_SUPPRESS_CONNECT_HEADERS, 1L);
    if (!p->max_keepalive || p->keepalive_expiry == 0) SET(CURLOPT_FORBID_REUSE, 1L);
    long max_age = LONG_MAX;
    if (p->keepalive_expiry >= 0 && p->keepalive_expiry < (double)LONG_MAX)
        max_age = (long)(p->keepalive_expiry < 1 ? 1 : p->keepalive_expiry);
    SET(CURLOPT_MAXAGE_CONN, max_age);
    SET(CURLOPT_NETRC, CURL_NETRC_IGNORED);
    SET(CURLOPT_SSL_VERIFYPEER, verify ? 1L : 0L);
    SET(CURLOPT_SSL_VERIFYHOST, verify ? 2L : 0L);
    SET(CURLOPT_PROXY_SSL_VERIFYPEER, verify ? 1L : 0L);
    SET(CURLOPT_PROXY_SSL_VERIFYHOST, verify ? 2L : 0L);
    if (ca_file && *ca_file) { SET(CURLOPT_CAINFO, ca_file); SET(CURLOPT_PROXY_CAINFO, ca_file); }
    if (ca_path && *ca_path) { SET(CURLOPT_CAPATH, ca_path); SET(CURLOPT_PROXY_CAPATH, ca_path); }
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
    if (p->http2) {
        CURLU *parsed = curl_url();
        char *scheme = NULL, *host = NULL, *port = NULL;
        if (!parsed || curl_url_set(parsed, CURLUPART_URL, url, 0) != CURLUE_OK ||
            curl_url_get(parsed, CURLUPART_SCHEME, &scheme, 0) != CURLUE_OK ||
            curl_url_get(parsed, CURLUPART_HOST, &host, 0) != CURLUE_OK ||
            curl_url_get(parsed, CURLUPART_PORT, &port, CURLU_DEFAULT_PORT) != CURLUE_OK) {
            curl_free(scheme); curl_free(host); curl_free(port); curl_url_cleanup(parsed);
            finish(t, 6); return t;
        }
        const char *keys[] = {scheme, host, port, proxy, no_proxy, verify ? "1" : "0",
                              ca_file ? ca_file : "", ca_path ? ca_path : ""};
        int failed = 0;
        for (size_t i = 0; i < sizeof(keys) / sizeof(keys[0]); i++) {
            struct curl_slist *next = curl_slist_append(t->connection_key, keys[i]);
            if (!next) { failed = 1; break; }
            t->connection_key = next;
        }
        curl_free(scheme); curl_free(host); curl_free(port); curl_url_cleanup(parsed);
        if (failed) { finish(t, 4); return t; }
    }
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
    if (upload_body) {
        if (body_consumed(upload_body)) { finish(t, 18); return t; }
        SET(CURLOPT_UPLOAD, 1L);
        SET(CURLOPT_READFUNCTION, on_upload);
        SET(CURLOPT_READDATA, t);
        SET(CURLOPT_SEEKFUNCTION, on_seek);
        SET(CURLOPT_SEEKDATA, t);
        SET(CURLOPT_INFILESIZE_LARGE, (curl_off_t)req_body_length(upload_body));
        SET(CURLOPT_CUSTOMREQUEST, method);
    } else if (has_body) {
        t->upload = malloc(length ? length : 1);
        if (!t->upload) { finish(t, 4); return t; }
        if (length) memcpy(t->upload, body, length);
        SET(CURLOPT_POSTFIELDS, t->upload);
        SET(CURLOPT_POSTFIELDSIZE_LARGE, (curl_off_t)length);
        SET(CURLOPT_CUSTOMREQUEST, method);
    }
    if (!strcmp(method, "HEAD")) SET(CURLOPT_NOBODY, 1L);
#undef SET
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
    if (!t->decoders_ready) {
        t->decoders_ready = 1;
        int error = configure_decoders(t);
        if (error >= 0) {
            finish(t, error);
            return -(int64_t)(error + 1);
        }
    }
    int64_t result = read_decoded(t, t->decoder_count - 1, buffer, capacity);
    if (result < 0) finish(t, (int)(-result - 1));
    return result;
}

int64_t req_transfer_read_raw(void *handle, unsigned char *buffer, size_t capacity) {
    return read_wire(handle, buffer, capacity);
}

void req_transfer_free(void *handle) {
    Transfer *t = handle;
    if (!t) return;
    finish(t, 16);
    Transfer **link = &t->pool->head;
    while (*link && *link != t) link = &(*link)->next;
    if (*link) *link = t->next;
    curl_slist_free_all(t->request_headers);
    curl_slist_free_all(t->connection_key);
    for (int i = 0; i < t->decoder_count; i++) {
        if (t->decoders[i].initialized) inflateEnd(&t->decoders[i].stream);
        clear_probe(&t->decoders[i]);
    }
    free(t->decoders);
    free(t->upload);
    free(t->headers);
    Pool *p = t->pool;
    free(t);
    release_pool(p);
}
