"""HTTP/2 errors tests."""
from ._http2_helpers import _client, _fails
from req import ErrorKind, Limits, encode_utf8
from std.testing import assert_equal, assert_true


def test_http2_goaway_during_response_recovers() raises:
    var client = _client(Limits(max_connections=1))
    var response = client.stream("GET", "/goaway-body")
    assert_equal(response.read_chunk(4).value(), encode_utf8("part"))
    var caught = False
    try:
        _ = response.read_chunk(4)
    except error:
        assert_equal(error.kind, ErrorKind.ReadError)
        caught = True
    assert_true(caught)
    assert_true(
        client.get("/echo").headers["X-Connection"]
        != response.headers["X-Connection"]
    )


def test_http2_reset_during_response_preserves_connection() raises:
    var client = _client(Limits(max_connections=1))
    var response = client.stream("GET", "/reset-body")
    assert_equal(response.read_chunk(4).value(), encode_utf8("part"))
    var caught = False
    try:
        _ = response.read_chunk(4)
    except error:
        assert_equal(error.kind, ErrorKind.ProtocolError)
        caught = True
    assert_true(caught)
    var next = client.get("/echo")
    assert_equal(next.headers["X-Connection"], response.headers["X-Connection"])
    assert_true(next.headers["X-Stream"] != response.headers["X-Stream"])


def test_http2_refused_stream_retries_once() raises:
    var client = _client(Limits(max_connections=1))
    var response = client.get("/refused-once?get")
    assert_equal(response.status_code, 200)
    assert_equal(response.http_version, "HTTP/2")
    assert_equal(response.json()["method"].string_value(), "GET")


def test_http2_invalid_frame_rejects_and_recovers() raises:
    var client = _client()
    _fails(client, "/bad-frame", ErrorKind.ReadError)


def test_http2_missing_status_rejects_and_recovers() raises:
    var client = _client()
    _fails(client, "/bad-headers", ErrorKind.ReadError)


def test_http2_eof_before_headers_rejects_and_recovers() raises:
    var client = _client()
    _fails(client, "/eof-headers", ErrorKind.ReadError)


def test_http2_eof_during_body_rejects_and_recovers() raises:
    var client = _client()
    _fails(client, "/eof-body", ErrorKind.ReadError)


def test_http2_content_length_mismatch_rejects_and_recovers() raises:
    var client = _client()
    _fails(client, "/bad-length", ErrorKind.ProtocolError)


def test_http2_invalid_hpack_rejects_and_recovers() raises:
    var client = _client()
    _fails(client, "/bad-hpack", ErrorKind.ReadError)
