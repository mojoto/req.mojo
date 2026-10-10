"""Transport tests."""
from req import Bytes, ErrorKind, Timeout
from req._transports.default import (
    CurlStream,
    close_pool,
    new_pool,
    release_pool,
)
from req._utils import decode_utf8
from std.os import getenv
from std.testing import assert_equal, assert_true


def test_native_transport() raises:
    var pool = new_pool()
    var response_headers: String
    var content = String()
    var largest = 0
    try:
        var response = CurlStream(
            pool,
            "GET",
            getenv("REQ_TEST_URL") + "/chunked",
            "",
            None,
            Timeout(),
            True,
            None,
        )
        response_headers = response.headers()
        while True:
            var chunk = response.read_chunk(3)
            if not chunk:
                break
            largest = max(largest, len(chunk.value()))
            content += decode_utf8(chunk.value())
        response.close()
    finally:
        close_pool(pool)
        release_pool(pool)
    assert_true("200 OK" in response_headers)
    assert_true(largest <= 3)
    assert_equal(content, "hello world")


def test_native_read_into_reuses_initialized_buffer() raises:
    var pool = new_pool()
    var rejected_empty = False
    var rejected_closed = False
    var valid_counts = True
    var collected = Bytes()
    var response: CurlStream
    try:
        response = CurlStream(
            pool,
            "GET",
            getenv("REQ_TEST_URL") + "/chunked",
            "",
            None,
            Timeout(),
            True,
            None,
        )
    except error:
        close_pool(pool)
        release_pool(pool)
        raise error
    response.owns_pool = pool
    var empty = Bytes()
    try:
        _ = response._read_into(empty)
    except error:
        rejected_empty = error.kind == ErrorKind.InvalidRequest
    var buffer = Bytes(length=4, fill=255)
    while True:
        var count = response._read_into(buffer)
        valid_counts = valid_counts and len(buffer) == 4 and 0 <= count <= 4
        if not count:
            break
        collected.extend(Span(buffer)[:count])
    var closed = not response.handle
    try:
        _ = response._read_into(buffer)
    except error:
        rejected_closed = error.kind == ErrorKind.StreamClosed
    assert_true(rejected_empty and rejected_closed and valid_counts and closed)
    assert_equal(decode_utf8(collected), "hello world")
