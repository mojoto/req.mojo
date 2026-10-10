"""Streaming tests."""
from req import Bytes, Client, ErrorKind, Headers, encode_utf8, stream
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


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


def test_transport_options_and_live_streams() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var posted = client.post(
        "/echo",
        content=encode_utf8("payload"),
        headers=Headers({"X-Reuse": "once"}),
    )
    assert_equal(posted.json()["body"].string_value(), "payload")
    var plain = client.get("/echo")
    assert_equal(plain.json()["method"].string_value(), "GET")
    assert_equal(plain.json()["body"].string_value(), "")
    with assert_raises():
        _ = plain.json()["headers"]["X-Reuse"]
    var head = client.head("/bytes")
    assert_equal(len(head.content()), 0)
    var active = client.stream("GET", "/bytes")
    posted.close()
    plain.close()
    var parallel = client.get("/chunked")
    assert_equal(parallel.text(), "hello world")
    var body = active.read()
    assert_equal(len(body), 200000)
    for i in range(len(body)):
        assert_equal(Int(body[i]), 48 + i % 10)
    var truncated = client.stream("GET", "/truncated")
    with assert_raises():
        _ = truncated.read()
    var recovered = client.get("/chunked")
    assert_equal(recovered.text(), "hello world")


def test_decoder_allocation_boundaries() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var expected = Bytes()
    for _ in range(8):
        for value in range(256):
            expected.append(UInt8(value))
    for path in [
        "/encoded?kind=identity&payload=binary",
        "/encoded?kind=five&payload=binary&fragment=1",
        "/encoded?kind=gzip&payload=binary",
        "/encoded?kind=identity&payload=binary",
    ]:
        var response = client.get(path)
        assert_equal(response.content(), expected)
    var caught = False
    try:
        _ = client.get("/encoded?kind=six&payload=binary")
    except error:
        assert_equal(error.kind, ErrorKind.DecodeError)
        caught = True
    assert_true(caught)
    var plain = client.get("/encoded?kind=identity&payload=binary")
    assert_equal(plain.content(), expected)


def test_response_headers_grow_and_reset_after_informational_status() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/headers-growth")
    assert_equal(response.status_code, 200)
    assert_equal(response.content(), encode_utf8("ok"))
    assert_true("X-Interim" not in response.headers)
    for i in range(60):
        assert_equal(
            response.headers["x-growth-" + String(i)].byte_length(), 4096
        )
    assert_equal(
        response.headers.get_all("X-Repeated"),
        List[String](["first", "second"]),
    )
    with assert_raises():
        _ = client.get("/headers-growth?overflow=1")
    assert_equal(client.get("/empty").status_code, 204)


def test_buffered_binary_chunks_and_copy_isolation() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for size in [0, 1, 16383, 16384, 16385, 65537]:
        var expected = Bytes(capacity=size)
        for i in range(size):
            expected.append(UInt8(i % 251))
        var response = client.post("/echo-bytes", content=expected.copy())
        assert_equal(response.content(), expected)
        var copied = response.read()
        assert_equal(copied, expected)
        if size:
            copied[0] = 255
            assert_equal(response.content(), expected)
        var collected = Bytes()
        while True:
            var chunk = response.read_chunk(16383)
            if not chunk:
                break
            assert_true(0 < len(chunk.value()) <= 16383)
            collected.extend(Span(chunk.value()))
        assert_equal(collected, expected)
        assert_true(not response.read_chunk())


def test_closed_implicit() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    assert_true(not client.is_closed())
    _ = client.get("/echo")
    client.close()
    assert_true(client.is_closed())
    client.close()
    with assert_raises():
        _ = client.get("/echo")
    with assert_raises():
        _ = client.context()


def test_closed_context() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    assert_true(not client.is_closed())
    with client.context() as scoped:
        _ = scoped.get("/echo")
    assert_true(client.is_closed())
    client.close()
    with assert_raises():
        _ = client.get("/echo")
    with assert_raises():
        _ = client.context()


def test_stream_single_byte_chunks() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    var content = Bytes()
    while True:
        var chunk = response.read_chunk(1)
        if not chunk:
            break
        assert_true(0 < len(chunk.value()) <= 1)
        for byte in chunk.value():
            content.append(byte)
    assert_equal(content, encode_utf8("hello world"))
    assert_true(response.is_closed())
    assert_true(not response.read_chunk())


def test_stream_small_chunks() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    var content = Bytes()
    while True:
        var chunk = response.read_chunk(3)
        if not chunk:
            break
        assert_true(0 < len(chunk.value()) <= 3)
        for byte in chunk.value():
            content.append(byte)
    assert_equal(content, encode_utf8("hello world"))
    assert_true(response.is_closed())
    assert_true(not response.read_chunk())


def test_stream_prime_sized_chunks() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    var content = Bytes()
    while True:
        var chunk = response.read_chunk(13)
        if not chunk:
            break
        assert_true(0 < len(chunk.value()) <= 13)
        for byte in chunk.value():
            content.append(byte)
    assert_equal(content, encode_utf8("hello world"))
    assert_true(response.is_closed())
    assert_true(not response.read_chunk())


def test_stream_block_sized_chunks() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    var content = Bytes()
    while True:
        var chunk = response.read_chunk(64)
        if not chunk:
            break
        assert_true(0 < len(chunk.value()) <= 64)
        for byte in chunk.value():
            content.append(byte)
    assert_equal(content, encode_utf8("hello world"))
    assert_true(response.is_closed())
    assert_true(not response.read_chunk())


def test_stream_unread() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    var caught = False
    try:
        _ = response.content()
    except error:
        assert_equal(error.kind, ErrorKind.StreamNotRead)
        caught = True
    assert_true(caught)
    _ = response.read()
    assert_equal(response.text(), "hello world")


def test_stream_consumed() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    _ = response.read_chunk(1)
    var caught = False
    try:
        _ = response.read()
    except error:
        assert_equal(error.kind, ErrorKind.StreamConsumed)
        caught = True
    assert_true(caught)


def test_stream_closed() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    response.close()
    var caught = False
    try:
        _ = response.read()
    except error:
        assert_equal(error.kind, ErrorKind.StreamClosed)
        caught = True
    assert_true(caught)


def test_stream_bad_chunk_size() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/chunked")
    for size in [0, -1]:
        with assert_raises():
            _ = response.read_chunk(size)
    assert_equal(response.read(), encode_utf8("hello world"))


def test_stream_failure_context() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/truncated")
    var caught = False
    try:
        _ = response.read()
    except error:
        assert_equal(error.kind, ErrorKind.ReadError)
        assert_equal(error.method.value(), "GET")
        assert_equal(error.url.value(), getenv("REQ_TEST_URL") + "/truncated")
        caught = True
    assert_true(caught)
    assert_true(response.is_closed())
    assert_equal(client.get("/echo").status_code, 200)
