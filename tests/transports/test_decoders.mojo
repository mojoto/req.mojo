"""Decoders tests."""
from req import Bytes, Client, ErrorKind, encode_utf8
from std.os import getenv
from std.testing import assert_equal, assert_true


def test_decoder_fragmented_body_and_chunk_size_matrix() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for encoding in [
        "identity",
        "gzip",
        "deflate",
        "raw-deflate",
        "multi",
        "multi-raw",
    ]:
        for payload in ["empty", "text", "binary"]:
            var expected = Bytes()
            var url = "/encoded?kind=" + encoding + "&fragment=1"
            if payload == "empty":
                url += "&empty=1"
            elif payload == "binary":
                url += "&payload=binary"
                for _ in range(8):
                    for byte in range(256):
                        expected.append(UInt8(byte))
            else:
                expected = encode_utf8("test 123")
            for size in [1, 5, 7, 13, 20, 65536]:
                var response = client.stream("GET", url)
                var received = Bytes()
                while True:
                    var chunk: Optional[Bytes]
                    try:
                        chunk = response.read_chunk(size)
                    except error:
                        raise Error(
                            encoding
                            + "/"
                            + payload
                            + "/"
                            + String(size)
                            + ": "
                            + String(error)
                        )
                    if not chunk:
                        break
                    assert_true(0 < len(chunk.value()) <= size)
                    for byte in chunk.value():
                        received.append(byte)
                assert_equal(
                    received,
                    expected,
                    encoding + "/" + payload + "/" + String(size),
                )
                assert_true(response.is_closed())
                assert_true(not response.read_chunk(size))


def test_decoder_truncated_streams() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for encoding in ["gzip", "deflate", "raw-deflate", "multi", "multi-raw"]:
        var url = "/encoded?kind=" + encoding + "&fragment=1&truncate=1"
        var response = client.stream("GET", url)
        var caught = False
        try:
            _ = response.read()
        except error:
            assert_equal(error.kind, ErrorKind.DecodeError, encoding)
            assert_equal(error.method.value(), "GET")
            assert_equal(error.url.value(), getenv("REQ_TEST_URL") + url)
            caught = True
        assert_true(caught, encoding)
        assert_true(response.is_closed())
        assert_equal(client.get("/echo").status_code, 200)


def test_decoder_concatenated_gzip_members() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for size in [1, 5, 20]:
        var response = client.stream(
            "GET", "/encoded?kind=gzip&fragment=1&concatenate=1"
        )
        var received = Bytes()
        while True:
            var chunk = response.read_chunk(size)
            if not chunk:
                break
            for byte in chunk.value():
                received.append(byte)
        assert_equal(received, encode_utf8("test 123test 123"))
        assert_true(response.is_closed())


def test_decoder_raw_deflate_header_ambiguity() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var expected = String()
    for _ in range(156):
        expected += "A"
    for size in [1, 7, 65536]:
        var response = client.stream(
            "GET", "/encoded?kind=ambiguous-deflate&fragment=1"
        )
        var received = Bytes()
        while True:
            var chunk = response.read_chunk(size)
            if not chunk:
                break
            for byte in chunk.value():
                received.append(byte)
        assert_equal(received, encode_utf8(expected))


def test_decoder_gzip() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=gzip")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_gzip_stream() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=gzip")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_deflate() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=deflate")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_deflate_stream() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=deflate")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_raw_deflate() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=raw-deflate")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_raw_deflate_stream() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=raw-deflate")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_multi() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=multi")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_multi_stream() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=multi")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_identity() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=identity")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_identity_stream() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=identity")
    assert_equal(response.read(), encode_utf8("test 123"))
    assert_equal(response.content(), encode_utf8("test 123"))


def test_decoder_gzip_empty() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=gzip&empty=1")
    assert_equal(response.content(), Bytes())


def test_decoder_gzip_zero() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=gzip&zero=1")
    assert_equal(response.content(), Bytes())


def test_decoder_deflate_empty() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=deflate&empty=1")
    assert_equal(response.content(), Bytes())


def test_decoder_deflate_zero() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=deflate&zero=1")
    assert_equal(response.content(), Bytes())


def test_decoder_identity_empty() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=identity&empty=1")
    assert_equal(response.content(), Bytes())


def test_decoder_identity_zero() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/encoded?kind=identity&zero=1")
    assert_equal(response.content(), Bytes())


def test_decoder_gzip_invalid() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var caught = False
    try:
        _ = client.get("/encoded?kind=gzip&invalid=1")
    except error:
        assert_equal(error.kind, ErrorKind.DecodeError)
        assert_equal(error.method.value(), "GET")
        assert_equal(
            error.url.value(),
            getenv("REQ_TEST_URL") + "/encoded?kind=gzip&invalid=1",
        )
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").status_code, 200)


def test_decoder_deflate_invalid() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var caught = False
    try:
        _ = client.get("/encoded?kind=deflate&invalid=1")
    except error:
        assert_equal(error.kind, ErrorKind.DecodeError)
        assert_equal(error.method.value(), "GET")
        assert_equal(
            error.url.value(),
            getenv("REQ_TEST_URL") + "/encoded?kind=deflate&invalid=1",
        )
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").status_code, 200)


def decoder_empty(encoding: String, buffered: Bool) raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var url = "/encoded?kind=" + encoding + "&zero=1"
    if buffered:
        assert_equal(client.get(url).content(), Bytes())
    else:
        var response = client.stream("GET", url)
        assert_equal(response.read(), Bytes())
        assert_true(response.is_closed())


def decoder_error(encoding: String) raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var url = "/encoded?kind=" + encoding + "&invalid=1"
    var response = client.stream("GET", url)
    var caught = False
    try:
        _ = response.read()
    except error:
        assert_equal(error.kind, ErrorKind.DecodeError)
        assert_equal(error.method.value(), "GET")
        assert_equal(error.url.value(), getenv("REQ_TEST_URL") + url)
        caught = True
    assert_true(caught, encoding)
    assert_true(response.is_closed())


def fragmented_gzip() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=gzip&fragment=1")
    var body = Bytes()
    while True:
        var chunk = response.read_chunk(1)
        if not chunk:
            break
        for byte in chunk.value():
            body.append(byte)
    assert_equal(body, encode_utf8("test 123"))
    assert_true(response.is_closed())


def test_decoder_empty_parameters() raises:
    decoder_empty("deflate", False)
    decoder_empty("deflate", True)
    decoder_empty("gzip", False)
    decoder_empty("gzip", True)
    decoder_empty("identity", False)
    decoder_empty("identity", True)


def test_decoder_error_parameters() raises:
    decoder_error("deflate")
    decoder_error("gzip")


def test_fragmented_gzip_parameters() raises:
    fragmented_gzip()
