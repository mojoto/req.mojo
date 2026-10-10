"""HTTP/2 connections tests."""
from ._http2_helpers import _client, _closed
from req import Bytes, Client, ErrorKind, Limits, Timeout
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def test_http2_reuse_and_multiplex_with_one_connection() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        limits=Limits(max_connections=1),
    )
    var url = getenv("REQ_TEST_HTTP2_URL")
    var first = client.stream("GET", url + "/bytes")
    var second = client.stream("GET", url + "/bytes")
    assert_equal(first.http_version, "HTTP/2")
    assert_equal(second.http_version, "HTTP/2")
    assert_equal(first.headers["X-Connection"], second.headers["X-Connection"])
    assert_true(first.headers["X-Stream"] != second.headers["X-Stream"])
    var two = second.read()
    var one = first.read()
    assert_equal(len(one), 200000)
    assert_equal(one, two)
    for i in range(len(one)):
        assert_equal(one[i], UInt8(i % 251))
    assert_equal(
        client.get(url + "/echo").headers["X-Connection"],
        first.headers["X-Connection"],
    )


def test_http2_pool_limit_across_origins() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        limits=Limits(max_connections=1),
    )
    var first = client.stream("GET", getenv("REQ_TEST_HTTP2_URL") + "/bytes")
    var caught = False
    try:
        _ = client.get(
            getenv("REQ_TEST_HTTP2_LIMITED_URL") + "/echo",
            timeout=Timeout(pool=0.05),
        )
    except error:
        caught = error.kind == ErrorKind.PoolTimeout
    assert_true(caught)
    first.close()
    assert_equal(
        client.get(getenv("REQ_TEST_HTTP2_LIMITED_URL") + "/echo").http_version,
        "HTTP/2",
    )


def test_http2_connect_proxy_and_certificate_validation() raises:
    var url = getenv("REQ_TEST_HTTP2_URL")
    for proxy in [getenv("REQ_TEST_PROXY"), getenv("REQ_TEST_TLS_PROXY")]:
        var client = Client(
            http2=True, ca_file=getenv("REQ_TEST_CA_FILE"), proxy=proxy
        )
        var response = client.get(url + "/echo")
        assert_equal(response.http_version, "HTTP/2")
        with assert_raises():
            _ = response.json()["headers"]["proxy-authorization"]
    var untrusted = Client(http2=True)
    var caught = False
    try:
        _ = untrusted.get(url + "/echo")
    except error:
        caught = error.kind == ErrorKind.TLSError
    assert_true(caught)


def test_http2_stream_reset_and_cancel_preserve_other_streams() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        limits=Limits(max_connections=1),
    )
    var url = getenv("REQ_TEST_HTTP2_URL")
    var first = client.stream("GET", url + "/bytes")
    var reset = False
    try:
        _ = client.get(url + "/reset")
    except error:
        reset = error.kind == ErrorKind.ProtocolError
    assert_true(reset)
    var second = client.stream("GET", url + "/bytes")
    first.close()
    assert_equal(len(second.read()), 200000)
    assert_equal(client.get(url + "/gzip").text(), "HTTP/2 compressed response")
    var head = client.head(url + "/bytes")
    assert_equal(head.http_version, "HTTP/2")
    assert_equal(head.content(), Bytes())


def test_http2_graceful_goaway_opens_new_connection() raises:
    var client = _client(Limits(max_connections=1))
    var first = client.get("/goaway")
    assert_equal(first.http_version, "HTTP/2")
    assert_equal(first.json()["method"].string_value(), "GET")
    var second = client.get("/echo")
    assert_true(first.headers["X-Connection"] != second.headers["X-Connection"])
    assert_equal(second.http_version, "HTTP/2")


def test_http2_cancel_preserves_connection_and_releases_stream_slot() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        base_url=getenv("REQ_TEST_HTTP2_LIMITED_URL"),
        limits=Limits(max_connections=1),
    )
    var response = client.stream("GET", "/bytes")
    var connection = response.headers["X-Connection"]
    response.close()
    response.close()
    var next = client.get("/echo", timeout=Timeout(pool=0.5))
    assert_equal(next.headers["X-Connection"], connection)
    assert_equal(next.http_version, "HTTP/2")


def test_http2_settings_reduce_stream_capacity() raises:
    var client = _client(Limits(max_connections=1))
    var first = client.stream("GET", "/bytes")
    var settings = client.get("/settings?max=1")
    assert_equal(
        settings.headers["X-Connection"], first.headers["X-Connection"]
    )
    var caught = False
    try:
        _ = client.get(
            "/echo", timeout=Timeout(pool=0.05, connect=0.01, read=0.01)
        )
    except error:
        assert_equal(error.kind, ErrorKind.PoolTimeout)
        caught = True
    assert_true(caught)
    assert_equal(len(first.read()), 200000)
    assert_equal(
        client.get("/echo").headers["X-Connection"],
        first.headers["X-Connection"],
    )


def test_http2_settings_increase_wakes_waiting_stream() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        base_url=getenv("REQ_TEST_HTTP2_LIMITED_URL"),
        limits=Limits(max_connections=1),
    )
    var first = client.stream("GET", "/settings-increase")
    var second = client.get(
        "/echo", timeout=Timeout(pool=1.0, connect=0.01, read=1.0)
    )
    assert_equal(second.headers["X-Connection"], first.headers["X-Connection"])
    assert_equal(len(first.read()), 200000)


def test_http2_physical_pool_limit_counts_connections_not_streams() raises:
    var client = _client(Limits(max_connections=2))
    var first = client.stream("GET", "/bytes")
    var second = client.stream("GET", "/bytes")
    var third = client.stream("GET", "/bytes")
    assert_equal(first.headers["X-Connection"], third.headers["X-Connection"])
    var other = client.get(
        getenv("REQ_TEST_HTTP2_LIMITED_URL") + "/echo",
        timeout=Timeout(pool=0.5),
    )
    assert_equal(other.http_version, "HTTP/2")
    assert_equal(len(first.read()), 200000)
    assert_equal(len(second.read()), 200000)
    assert_equal(len(third.read()), 200000)


def test_http2_client_close_cancels_all_streams() raises:
    var client = _client()
    var one = client.stream("GET", "/bytes")
    var two = client.stream("GET", "/bytes")
    client.close()
    _closed(one)
    _closed(two)
    var caught = False
    try:
        _ = client.get("/echo")
    except error:
        assert_equal(error.kind, ErrorKind.ClientClosed)
        caught = True
    assert_true(caught)


def test_http2_keepalive_disabled_and_expired() raises:
    for limits in [
        Limits(max_keepalive_connections=0),
        Limits(keepalive_expiry=0.0),
    ]:
        var client = _client(limits)
        var first = client.get("/echo").headers["X-Connection"]
        assert_true(client.get("/echo").headers["X-Connection"] != first)
    var expiring = _client(Limits(keepalive_expiry=0.03))
    var connection = expiring.get("/echo").headers["X-Connection"]
    var other = _client()
    _ = other.get("/slow-headers")
    assert_true(expiring.get("/echo").headers["X-Connection"] != connection)
