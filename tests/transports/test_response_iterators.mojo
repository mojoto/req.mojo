"""Response iteration over real protocol and compression fixtures."""

from std.os import getenv
from std.testing import assert_equal, assert_true
from req import Client, Bytes, ErrorKind, Timeout, encode_utf8


def test_iter_text_returns_before_stream_eof() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), timeout=Timeout(read=0.1)
    )
    var response = client.stream("GET", "/open-text")
    var chunks = response.iter_text(1)
    assert_equal(chunks.next_chunk().value(), "你")
    assert_true(not response.is_closed())
    response.close()


def test_context_iter_text_returns_before_stream_eof() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), timeout=Timeout(read=0.1)
    )
    var text: String
    var closed: Bool
    with client.stream("GET", "/open-text") as response:
        var chunks = response.iter_text(1)
        text = chunks.next_chunk().value()
        closed = response.is_closed()
    assert_equal(text, "你")
    assert_true(not closed)


def test_iter_lines_returns_before_stream_eof() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), timeout=Timeout(read=0.1)
    )
    var response = client.stream("GET", "/open-text")
    var lines = response.iter_lines()
    assert_equal(lines.next_chunk().value(), "你好")
    assert_true(not response.is_closed())
    response.close()


def test_context_iter_lines_returns_before_stream_eof() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), timeout=Timeout(read=0.1)
    )
    var text: String
    var closed: Bool
    with client.stream("GET", "/open-text") as response:
        var lines = response.iter_lines()
        text = lines.next_chunk().value()
        closed = response.is_closed()
    assert_equal(text, "你好")
    assert_true(not closed)


def test_iter_bytes_native_compression_matrix() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for encoding in [
        "identity",
        "gzip",
        "deflate",
        "raw-deflate",
        "multi",
        "multi-raw",
    ]:
        for size in [1, 3, 7, 65536]:
            var response = client.stream(
                "GET", "/encoded?kind=" + encoding + "&fragment=1"
            )
            var result = Bytes()
            for chunk in response.iter_bytes(size):
                result.extend(Span(chunk))
                assert_true(0 < len(chunk) <= size)
            assert_equal(result, encode_utf8("test 123"))
            assert_true(response.is_closed())


def test_iter_raw_gzip_preserves_compressed_bytes() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=gzip")
    var wire = Bytes()
    for chunk in response.iter_raw(3):
        wire.extend(Span(chunk))
    assert_equal(Int(wire[0]), 31)
    assert_equal(Int(wire[1]), 139)
    assert_equal(len(wire), Int(response.headers["Content-Length"]))
    assert_true(wire != encode_utf8("test 123"))
    assert_true(response.is_closed())


def test_iter_raw_does_not_decode_invalid_compression() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=gzip&invalid=1")
    var result = Bytes()
    for chunk in response.iter_raw():
        result.extend(Span(chunk))
    assert_equal(result, encode_utf8("invalid"))


def test_iter_raw_unsupported_encoding_is_accessible() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/unsupported-encoding")
    var result = Bytes()
    for chunk in response.iter_raw():
        result.extend(Span(chunk))
    assert_equal(result, encode_utf8("content"))
    var caught = False
    try:
        _ = client.get("/unsupported-encoding")
    except error:
        caught = error.kind == ErrorKind.DecodeError
    assert_true(caught)


def test_iter_raw_chunked_removes_transfer_framing() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    var result = Bytes()
    for chunk in response.iter_raw(2):
        result.extend(Span(chunk))
    assert_equal(result, encode_utf8("hello world"))


def test_iterators_native_empty_and_head() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for method in ["GET", "HEAD"]:
        var response = client.stream(method, "/empty")
        var total = 0
        for chunk in response.iter_bytes():
            total += len(chunk)
        assert_equal(total, 0)
        assert_true(response.is_closed())


def test_iterators_http2_compression_and_lines() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        base_url=getenv("REQ_TEST_HTTP2_URL"),
    )
    var response = client.stream("GET", "/gzip")
    var result = String()
    for chunk in response.iter_text(2):
        result += chunk
    assert_equal(result, "HTTP/2 compressed response")
    assert_equal(response.http_version, "HTTP/2")
    assert_true(response.is_closed())


def test_iterators_decode_failure_releases_pool_slot() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/bad-gzip")
    var caught = False
    try:
        for chunk in response.iter_bytes():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.DecodeError
    assert_true(caught)
    assert_true(response.is_closed())
    assert_equal(client.get("/empty").status_code, 204)


def test_iterators_http2_protocol_failure_propagates() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        base_url=getenv("REQ_TEST_HTTP2_URL"),
    )
    var response = client.stream("GET", "/reset-body")
    var caught = False
    try:
        for chunk in response.iter_bytes():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.ProtocolError
    assert_true(caught)
    assert_true(response.is_closed())


def test_iter_raw_http2_compressed_bytes() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        base_url=getenv("REQ_TEST_HTTP2_URL"),
    )
    var response = client.stream("GET", "/gzip")
    var wire = Bytes()
    for chunk in response.iter_raw(2):
        wire.extend(Span(chunk))
    assert_equal(Int(wire[0]), 31)
    assert_equal(Int(wire[1]), 139)
    assert_equal(len(wire), Int(response.headers["Content-Length"]))
    assert_true(response.is_closed())
