from std.testing import TestSuite, assert_equal, assert_true, assert_raises
from std.os import getenv
from req import Client, Bytes, ErrorKind, HTTPError, stream


def test_stream_states() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/bytes")
    assert_true(not response.is_closed())
    var caught = False
    try:
        _ = response.content()
    except error:
        assert_equal(error.kind, ErrorKind.StreamNotRead)
        caught = True
    assert_true(caught)
    var count = 0
    while True:
        var chunk = response.read_chunk(101)
        if not chunk:
            break
        assert_true(0 < len(chunk.value()) <= 101)
        count += len(chunk.value())
    assert_equal(count, 200000)
    assert_true(response.is_closed())
    assert_true(not response.read_chunk())
    with assert_raises():
        _ = response.read()
    response.close()


def test_stream_read_cache_and_lifetimes() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    _ = response.read()
    assert_equal(response.text(), "hello world")
    assert_equal(len(response.read()), 11)
    assert_true(response.is_closed())
    var active = client.stream("GET", "/bytes")
    client.close()
    with assert_raises():
        _ = active.read_chunk()
    active.close()
    var owned = stream("GET", getenv("REQ_TEST_URL") + "/chunked")
    _ = owned.read()
    assert_equal(owned.text(), "hello world")


def test_stream_close_and_failure() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/bytes")
    response.close()
    response.close()
    with assert_raises():
        _ = response.read_chunk()
    var truncated = client.stream("GET", "/truncated")
    with assert_raises():
        _ = truncated.read()
    assert_true(truncated.is_closed())
    var text: String
    with client.stream("GET", "/chunked") as content:
        _ = content.read()
        text = content.text()
    assert_equal(text, "hello world")


def test_incremental_decompression() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for path in ["/gzip", "/deflate"]:
        var buffered = client.get(path)
        assert_equal(len(buffered.content()), 160000)
        var response = client.stream("GET", path)
        var count = 0
        while True:
            var chunk = response.read_chunk(123)
            if not chunk:
                break
            count += len(chunk.value())
        assert_equal(count, 160000)
    for path in ["/bad-gzip", "/unsupported-encoding"]:
        with assert_raises():
            _ = client.get(path)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
