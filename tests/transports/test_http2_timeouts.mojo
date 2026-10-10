"""HTTP/2 timeouts tests."""
from ._http2_helpers import _client
from req import Client, ErrorKind, Limits, RequestBody, Timeout, encode_utf8
from std.os import getenv
from std.testing import assert_equal, assert_true


def test_http2_peer_stream_limit_reports_pool_timeout() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        limits=Limits(max_connections=1),
    )
    var url = getenv("REQ_TEST_HTTP2_LIMITED_URL")
    var first = client.stream("GET", url + "/bytes")
    var caught = False
    try:
        _ = client.get(
            url + "/echo", timeout=Timeout(pool=0.06, connect=0.01, read=0.01)
        )
    except error:
        caught = error.kind == ErrorKind.PoolTimeout
    assert_true(caught)
    assert_equal(len(first.read()), 200000)
    assert_equal(client.get(url + "/echo").http_version, "HTTP/2")


def test_http2_read_timeout_before_headers_preserves_connection() raises:
    var client = _client(Limits(max_connections=1))
    var previous = client.get("/echo").headers["X-Connection"]
    var caught = False
    try:
        _ = client.get("/slow-headers", timeout=Timeout(read=0.05))
    except error:
        assert_equal(error.kind, ErrorKind.ReadTimeout)
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").headers["X-Connection"], previous)


def test_http2_read_timeout_during_body_preserves_other_streams() raises:
    var client = _client(Limits(max_connections=1))
    var slow = client.stream("GET", "/slow-body", timeout=Timeout(read=0.05))
    var healthy = client.stream("GET", "/bytes")
    assert_equal(slow.headers["X-Connection"], healthy.headers["X-Connection"])
    assert_equal(slow.read_chunk(4).value(), encode_utf8("part"))
    var caught = False
    try:
        _ = slow.read_chunk(4)
    except error:
        assert_equal(error.kind, ErrorKind.ReadTimeout)
        caught = True
    assert_true(caught)
    assert_equal(len(healthy.read()), 200000)
    assert_equal(
        client.get("/echo").headers["X-Connection"],
        healthy.headers["X-Connection"],
    )


def test_http2_write_timeout_on_exhausted_window_preserves_connection() raises:
    var client = _client(Limits(max_connections=1))
    var previous = client.get("/echo").headers["X-Connection"]
    var caught = False
    try:
        _ = client.post(
            "/stall-upload",
            body=RequestBody.from_file(getenv("REQ_TEST_LARGE_FILE")),
            timeout=Timeout(write=0.05, read=1.0),
        )
    except error:
        assert_equal(error.kind, ErrorKind.WriteTimeout)
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").headers["X-Connection"], previous)


def test_http2_connect_timeout_during_tls_handshake() raises:
    var client = Client(http2=True, verify=False)
    var caught = False
    try:
        _ = client.get(
            getenv("REQ_TEST_BLACKHOLE_URL"), timeout=Timeout(connect=0.05)
        )
    except error:
        assert_equal(error.kind, ErrorKind.ConnectTimeout)
        caught = True
    assert_true(caught)


def test_http2_disabled_timeout_allows_delayed_response() raises:
    var client = _client()
    assert_equal(
        client.get("/slow-body", timeout=Timeout.disabled()).text(), "partrest"
    )
    assert_equal(
        client.get("/slow-headers", timeout=Timeout.disabled()).status_code, 200
    )
