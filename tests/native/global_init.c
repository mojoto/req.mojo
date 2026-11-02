#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <curl/curl.h>
#include <pthread.h>
#include <stdatomic.h>
#include <time.h>

static atomic_int init_calls;
static CURLcode counted_init(long flags) {
    atomic_fetch_add(&init_calls, 1);
    /* Keep simultaneous first callers inside initialization together. */
    struct timespec delay = {0, 100000000};
    nanosleep(&delay, NULL);
    return curl_global_init(flags);
}
#define curl_global_init counted_init
#include "../../req/_transports/_curl.c"
#undef curl_global_init

static pthread_mutex_t gate = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t ready = PTHREAD_COND_INITIALIZER;
static int started;

static void *worker(void *unused) {
    (void)unused;
    assert(!pthread_mutex_lock(&gate));
    while (!started) assert(!pthread_cond_wait(&ready, &gate));
    assert(!pthread_mutex_unlock(&gate));
    (void)req_http2_supported();
    void *pool = req_pool_new(10, 5, 5, 1, 0);
    assert(pool);
    req_pool_release(pool);
    return NULL;
}

int main(void) {
    pthread_t workers[16];
    for (int i = 0; i < 16; i++) assert(!pthread_create(&workers[i], NULL, worker, NULL));
    assert(!pthread_mutex_lock(&gate));
    started = 1;
    assert(!pthread_cond_broadcast(&ready));
    assert(!pthread_mutex_unlock(&gate));
    for (int i = 0; i < 16; i++) assert(!pthread_join(workers[i], NULL));
    assert(atomic_load(&init_calls) == 1);
    puts("Verified one global initialization across 16 independent workers");
    return 0;
}
