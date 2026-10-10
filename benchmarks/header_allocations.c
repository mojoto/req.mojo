#include <assert.h>
#include <stdio.h>
#include <stdlib.h>
static size_t allocation_calls;
static void *counted_realloc(void *pointer, size_t size) {
    allocation_calls++;
    return realloc(pointer, size);
}
#define realloc counted_realloc
#include "req/_transports/_curl.c"
#undef realloc
int main(void) {
    assert(curl_global_init(CURL_GLOBAL_DEFAULT) == CURLE_OK);
    Transfer t = {0};
    t.easy = curl_easy_init();
    assert(t.easy);
    t.error = -1;
    char status[] = "HTTP/1.1 200 OK\r\n";
    assert(on_headers(status, 1, strlen(status), &t) == strlen(status));
    for (int i = 0; i < 64; i++) {
        char line[100];
        int n = snprintf(line, sizeof line, "X-Bench-Header-Name-%d: %d\r\n", i, i);
        assert(n > 0);
        assert(on_headers(line, 1, (size_t)n, &t) == (size_t)n);
    }
    assert(strstr(t.headers, "X-Bench-Header-Name-63: 63\r\n"));
    printf("HEADER_ALLOCATIONS %zu\n", allocation_calls);
    t.header_ready = 1;
    size_t before = t.header_size;
    char trailer[] = "X-Trailer: ignored\r\n";
    assert(on_headers(trailer, 1, strlen(trailer), &t) == strlen(trailer));
    assert(t.header_size == before);
    assert(on_headers(status, 1, strlen(status), &t) == strlen(status));
    assert(t.header_size == strlen(status));
    /* Exactly 256 KiB is accepted, one more byte is rejected. */
    size_t remaining = 262144 - t.header_size;
    char *large = malloc(remaining);
    assert(large);
    memset(large, 'a', remaining);
    assert(on_headers(large, 1, remaining, &t) == remaining);
    assert(t.header_size == 262144 && t.headers[t.header_size] == 0);
    assert(on_headers(large, 1, 1, &t) == 0 && t.error == 6);
    free(large);
    free(t.headers);
    curl_easy_cleanup(t.easy);
    curl_global_cleanup();
    puts("HEADER_BOUNDARIES_PASS");
}
