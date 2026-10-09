/* A pull-based, single-threaded libcurl bridge. Policy lives in Mojo. */
#include <curl/curl.h>
#include <limits.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

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
        if (status >= 200) t->header_ready = 1;
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

int64_t req_transfer_read(void *handle, unsigned char *buffer, size_t capacity) {
    Transfer *t = handle;
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

void req_transfer_free(void *handle) {
    Transfer *t = handle;
    if (!t) return;
    finish(t, 16);
    Transfer **link = &t->pool->head;
    while (*link && *link != t) link = &(*link)->next;
    if (*link) *link = t->next;
    curl_slist_free_all(t->request_headers);
    free(t->upload);
    free(t->headers);
    Pool *p = t->pool;
    free(t);
    release_pool(p);
}
