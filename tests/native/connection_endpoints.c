#define _POSIX_C_SOURCE 200809L
#include <assert.h>
#include <netinet/in.h>
#include <sys/socket.h>
#include <unistd.h>

static unsigned local_probes, remote_probes;
static int counted_getsockname(int fd, struct sockaddr *address, socklen_t *size) {
    local_probes++;
    return getsockname(fd, address, size);
}
static int counted_getpeername(int fd, struct sockaddr *address, socklen_t *size) {
    remote_probes++;
    return getpeername(fd, address, size);
}
#define getsockname counted_getsockname
#define getpeername counted_getpeername
#include "../../req/_transports/_curl.c"
#undef getsockname
#undef getpeername

static void check_endpoints(int family) {
    int listener = socket(family, SOCK_STREAM, 0);
    assert(listener >= 0);
    struct sockaddr_storage address = {0};
    socklen_t size;
    if (family == AF_INET) {
        struct sockaddr_in *v4 = (struct sockaddr_in *)&address;
        v4->sin_family = AF_INET;
        v4->sin_addr.s_addr = htonl(0x7f000001);
        size = sizeof(*v4);
    } else {
        struct sockaddr_in6 *v6 = (struct sockaddr_in6 *)&address;
        v6->sin6_family = AF_INET6;
        v6->sin6_addr = in6addr_loopback;
        size = sizeof(*v6);
    }
    assert(!bind(listener, (struct sockaddr *)&address, size));
    assert(!listen(listener, 1));
    assert(!getsockname(listener, (struct sockaddr *)&address, &size));
    int client = socket(family, SOCK_STREAM, 0);
    assert(client >= 0 && !connect(client, (struct sockaddr *)&address, size));
    int peer = accept(listener, NULL, NULL);
    assert(peer >= 0);
    local_probes = remote_probes = 0;
    Connection connection = {0};
    connection.socket = client;
    for (int i = 0; i < 1024; i++) assert(cache_endpoints(&connection));
    assert(local_probes == 1 && remote_probes == 1);
    assert(!strcmp(connection.local_ip, family == AF_INET ? "127.0.0.1" : "::1"));
    assert(!strcmp(connection.remote_ip, connection.local_ip));
    int expected_port = family == AF_INET
        ? ntohs(((struct sockaddr_in *)&address)->sin_port)
        : ntohs(((struct sockaddr_in6 *)&address)->sin6_port);
    assert(connection.remote_port == expected_port && connection.local_port > 0);
    Connection retry = {0};
    retry.socket = -1;
    assert(!cache_endpoints(&retry) && !retry.endpoints_cached);
    retry.socket = client;
    assert(cache_endpoints(&retry));
    assert(local_probes == 3 && remote_probes == 2);
    assert(retry.local_port == connection.local_port);
    assert(!close(peer) && !close(client) && !close(listener));
}

static void check_key_reuse(void) {
    Pool pool = {0};
    Connection connection = {0};
    pool.connections = &connection;
    int error = 0;
    ConnectionKey *first = request_key(&pool, "http://example.test/a", "", "", 1, "ca", "dir", &error);
    assert(first && first->refs == 1);
    connection.key = retain_key(first);
    ConnectionKey *again = request_key(&pool, "http://example.test/a", "", "", 1, "ca", "dir", &error);
    assert(again == first && first->refs == 3);
    release_key(first);
    release_key(again);
    assert(connection.key->refs == 1);
    ConnectionKey *path = request_key(&pool, "http://example.test/b", "", "", 1, "ca", "dir", &error);
    assert(path && path != connection.key && same_key(path, connection.key));
    release_key(path);
    const char *urls[] = {"https://example.test/a", "http://other.test/a", "http://example.test:81/a"};
    for (size_t i = 0; i < sizeof(urls) / sizeof(urls[0]); i++) {
        ConnectionKey *changed = request_key(&pool, urls[i], "", "", 1, "ca", "dir", &error);
        assert(changed && !same_key(changed, connection.key));
        release_key(changed);
    }
    for (int i = 0; i < 5; i++) {
        ConnectionKey *changed = request_key(&pool, "http://example.test/a",
            i == 0 ? "http://proxy.test" : "", i == 1 ? "example.test" : "",
            i == 2 ? 0 : 1, i == 3 ? "other-ca" : "ca", i == 4 ? "other-dir" : "dir", &error);
        assert(changed && !same_key(changed, connection.key));
        release_key(changed);
    }
    release_key(connection.key);
    connection.key = NULL;
    assert(!request_key(&pool, "invalid", "", "", 1, "", "", &error) && error == 6);
}

int main(void) {
    check_endpoints(AF_INET);
    check_endpoints(AF_INET6);
    check_key_reuse();
    puts("Verified IPv4/IPv6 endpoint reuse and failed-probe retries");
    return 0;
}
