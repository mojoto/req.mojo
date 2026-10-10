#define _POSIX_C_SOURCE 200809L
#include <pthread.h>
#include <stdatomic.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <sys/resource.h>
#include <time.h>

extern int mojo_worker(long index);
#define MAX_WORKERS 128
#define MAX_SAMPLES 65536

static pthread_mutex_t mutex = PTHREAD_MUTEX_INITIALIZER;
static pthread_cond_t cond = PTHREAD_COND_INITIALIZER;
static int ready, released;
static uint64_t start, deadline;
static _Atomic uint64_t peak, inflight;
static struct {
    uint64_t count, errors, finished, samples[MAX_SAMPLES];
    size_t sample_count;
    int reused;
} results[MAX_WORKERS];

uint64_t bench_now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return (uint64_t)t.tv_sec * 1000000000ULL + t.tv_nsec;
}

static uint64_t bench_cpu_us(void) {
    struct rusage usage;
    if (getrusage(RUSAGE_SELF, &usage)) abort();
    return ((uint64_t)usage.ru_utime.tv_sec + usage.ru_stime.tv_sec) * 1000000ULL
        + usage.ru_utime.tv_usec + usage.ru_stime.tv_usec;
}

uint64_t bench_wait(void) {
    pthread_mutex_lock(&mutex);
    ready++;
    pthread_cond_broadcast(&cond);
    while (!released) pthread_cond_wait(&cond, &mutex);
    pthread_mutex_unlock(&mutex);
    return deadline;
}

void bench_sample(long index, uint64_t duration) {
    size_t count = results[index].sample_count;
    if (count < MAX_SAMPLES) {
        results[index].samples[count] = duration;
        results[index].sample_count++;
    }
}

void bench_enter(void) {
    uint64_t count = atomic_fetch_add(&inflight, 1) + 1;
    uint64_t previous = atomic_load(&peak);
    while (count > previous && !atomic_compare_exchange_weak(&peak, &previous, count)) {}
}

void bench_leave(void) {
    atomic_fetch_sub(&inflight, 1);
}

void bench_finish(long index, uint64_t count, uint64_t errors, int reused) {
    results[index].count = count;
    results[index].errors = errors;
    results[index].reused = reused;
    results[index].finished = bench_now();
}

static void *worker(void *index) {
    if (mojo_worker((long)index) != 0) abort();
    return NULL;
}

int bench_run(long workers, long seconds) {
    if (workers < 1 || workers > MAX_WORKERS || seconds < 1) return 1;
    pthread_t threads[MAX_WORKERS];
    for (long i = 0; i < workers; i++) {
        if (pthread_create(&threads[i], NULL, worker, (void *)i)) abort();
    }
    pthread_mutex_lock(&mutex);
    while (ready < workers) pthread_cond_wait(&cond, &mutex);
    start = bench_now();
    deadline = start + (uint64_t)seconds * 1000000000ULL;
    uint64_t cpu_start = bench_cpu_us();
    released = 1;
    pthread_cond_broadcast(&cond);
    pthread_mutex_unlock(&mutex);
    for (long i = 0; i < workers; i++) pthread_join(threads[i], NULL);
    uint64_t cpu_elapsed = bench_cpu_us() - cpu_start;

    uint64_t count = 0, errors = 0, end = start;
    int reused = 1;
    for (long i = 0; i < workers; i++) {
        count += results[i].count;
        errors += results[i].errors;
        reused &= results[i].reused;
        if (results[i].finished > end) end = results[i].finished;
    }
    printf("{\"requests\":%llu,\"errors\":%llu,\"elapsed_ns\":%llu,\"client_cpu_us\":%llu,"
           "\"connections_reused\":%s,\"peak_inflight\":%llu,\"latency_ns\":[",
           (unsigned long long)count, (unsigned long long)errors,
           (unsigned long long)(end - start), (unsigned long long)cpu_elapsed,
           reused ? "true" : "false",
           (unsigned long long)atomic_load(&peak));
    int comma = 0;
    for (long i = 0; i < workers; i++) {
        for (size_t j = 0; j < results[i].sample_count; j++) {
            if (comma) putchar(',');
            comma = 1;
            printf("%llu", (unsigned long long)results[i].samples[j]);
        }
    }
    puts("]}");
    return errors ? 1 : 0;
}
