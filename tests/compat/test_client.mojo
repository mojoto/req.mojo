"""Pinned v0.28.1 scenarios adapted to the native synchronous API."""
from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from req import (
    Client,
    Request,
    Response,
    Headers,
    QueryParams,
    Auth,
    Timeout,
    Bytes,
    JSONValue,
    encode_utf8,
    ErrorKind,
)
import req


def test_client_get() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "GET")


def test_api_get() raises:
    var response = req.get(getenv("REQ_TEST_URL") + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "GET")


def test_client_post() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "POST")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_post() raises:
    var response = req.post(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "POST")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_client_options() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.options("/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "OPTIONS")


def test_api_options() raises:
    var response = req.options(getenv("REQ_TEST_URL") + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "OPTIONS")


def test_client_head() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.head("/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.content(), Bytes())


def test_api_head() raises:
    var response = req.head(getenv("REQ_TEST_URL") + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.content(), Bytes())


def test_client_put() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.put(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PUT")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_put() raises:
    var response = req.put(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PUT")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_client_patch() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.patch(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PATCH")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_patch() raises:
    var response = req.patch(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PATCH")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_client_delete() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.delete(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "DELETE")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_delete() raises:
    var response = req.delete(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "DELETE")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_post_json() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/echo", json=JSONValue.parse('{"hello":"world"}')
    )
    assert_equal(response.json()["body"].string_value(), '{"hello":"world"}')
    assert_equal(
        response.json()["headers"]["Content-Type"].string_value(),
        "application/json",
    )


def test_build_request() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var request = client.build_request(
        "GET", "/echo", params=QueryParams("a=1")
    )
    assert_equal(request.method, "GET")
    assert_equal(request.url.query(), "a=1")
    assert_equal(request.url.path(), "/echo")
    assert_true(not request.content)


def test_build_post_request() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var request = client.build_request(
        "POST", "/echo", json=JSONValue.parse('{"hello":"world"}')
    )
    assert_equal(request.method, "POST")
    assert_equal(request.headers["Content-Type"], "application/json")
    assert_equal(request.content.value(), encode_utf8('{"hello":"world"}'))


def test_base_url_without_trailing_slash() raises:
    var client = Client(base_url="http://example.com")
    assert_equal(
        String(client.build_request("GET", "/testing").url),
        "http://example.com/testing",
    )


def test_merge_relative_url() raises:
    var client = Client(base_url="http://example.com")
    assert_equal(
        String(client.build_request("GET", "testing").url),
        "http://example.com/testing",
    )


def test_merge_relative_url_with_file_base() raises:
    var client = Client(base_url="http://example.com/some/path")
    assert_equal(
        String(client.build_request("GET", "testing").url),
        "http://example.com/some/testing",
    )


def test_merge_relative_url_with_directory_base() raises:
    var client = Client(base_url="http://example.com/some/path/")
    assert_equal(
        String(client.build_request("GET", "testing").url),
        "http://example.com/some/path/testing",
    )


def test_merge_relative_url_with_dotted_path() raises:
    var client = Client(base_url="http://example.com/some/path/")
    assert_equal(
        String(client.build_request("GET", "../testing").url),
        "http://example.com/some/testing",
    )


def test_merge_absolute_path() raises:
    var client = Client(base_url="http://example.com/some/path/")
    assert_equal(
        String(client.build_request("GET", "/testing").url),
        "http://example.com/testing",
    )


def test_merge_relative_url_with_path_including_colon() raises:
    var client = Client(base_url="http://example.com/some/path/")
    assert_equal(
        String(client.build_request("GET", "./testing:a").url),
        "http://example.com/some/path/testing:a",
    )


def test_merge_relative_url_with_encoded_slashes() raises:
    var client = Client(base_url="http://example.com/some/path/")
    assert_equal(
        String(client.build_request("GET", "testing%2Fpath").url),
        "http://example.com/some/path/testing%2Fpath",
    )


def test_merge_absolute_url() raises:
    var client = Client(base_url="http://example.com/some/path/")
    assert_equal(
        String(client.build_request("GET", "http://example.com/else").url),
        "http://example.com/else",
    )


def test_client_invalid_url() raises:
    var client = Client()
    with assert_raises():
        _ = client.get("invalid://example.com")


def test_api_invalid_url() raises:
    with assert_raises():
        _ = req.get("invalid://example.com")


def test_header_merge() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        headers=Headers({"X-Default": "value", "X-Conflict": "old"}),
    )
    var request = client.build_request(
        "GET", "/echo", headers=Headers({"X-Extra": "yes", "x-conflict": "new"})
    )
    assert_equal(request.headers["X-Default"], "value")
    assert_equal(request.headers["X-Extra"], "yes")
    assert_equal(request.headers["X-Conflict"], "new")
    assert_equal(
        client.build_request("GET", "/echo").headers["X-Conflict"], "old"
    )


def test_repeated_headers() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        headers=Headers(
            List[Tuple[String, String]]([("X", "one"), ("X", "two")])
        ),
    )
    var request = client.build_request("GET", "/echo")
    assert_equal(request.headers.get_all("x"), List[String](["one", "two"]))
    assert_true(not request.headers.get("missing"))


def test_remove_header() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), headers=Headers({"X-Default": "value"})
    )
    var request = client.build_request("GET", "/echo")
    request.headers.remove("X-Default")
    var response = client.send(request)
    with assert_raises():
        _ = response.json()["headers"]["X-Default"]


def test_wire_headers() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post("/echo", content=encode_utf8("test 123"))
    var headers = response.json()["headers"]
    assert_equal(headers["Content-Length"].string_value(), "8")
    assert_equal(
        headers["Host"].string_value(),
        String(req.URL(getenv("REQ_TEST_URL")).host())
        + ":"
        + String(req.URL(getenv("REQ_TEST_URL")).port()),
    )
    assert_true("gzip" in headers["Accept-Encoding"].string_value())


def test_queryparams_merge() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), params=QueryParams("a=client&b=client")
    )
    var response = client.get(
        "/echo?a=url&c=url", params=QueryParams("a=request&a=second")
    )
    var params = QueryParams(response.json()["query"].string_value())
    assert_equal(params.get_all("a"), List[String](["request", "second"]))
    assert_equal(params["b"], "client")
    assert_equal(params["c"], "url")
    assert_equal(
        client.build_request("GET", "/echo").url.query_params()["a"], "client"
    )


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


def test_api_stream() raises:
    var response = req.stream("GET", getenv("REQ_TEST_URL") + "/chunked")
    assert_equal(response.read(), encode_utf8("hello world"))
    assert_equal(response.read(), encode_utf8("hello world"))
    assert_equal(response.text(), "hello world")


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


def test_send_timeout_override() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        timeout=Timeout(connect=1.0, read=0.05, write=1.0),
    )
    var request = client.build_request("GET", "/slow-body")
    var response = client.send(request, timeout=Timeout.disabled())
    assert_equal(response.text(), "partrest")
    var caught = False
    try:
        _ = client.send(request)
    except error:
        assert_equal(error.kind, ErrorKind.ReadTimeout)
        caught = True
    assert_true(caught)


def test_client_raise_for_status() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/status/404")
    assert_equal(response.status_code, 404)
    var caught = False
    try:
        response.raise_for_status()
    except error:
        assert_equal(error.kind, ErrorKind.HTTPStatusError)
        assert_equal(error.status_code.value(), 404)
        assert_equal(error.method.value(), "GET")
        assert_equal(error.url.value(), getenv("REQ_TEST_URL") + "/status/404")
        caught = True
    assert_true(caught)


def test_send_request_preserves_raw_headers() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        headers=Headers({"X-Default": "default"}),
    )
    var response = client.send(
        Request(
            "GET",
            getenv("REQ_TEST_URL") + "/echo",
            headers=Headers({"X-Raw": "raw"}),
        )
    )
    assert_equal(response.json()["headers"]["X-Raw"].string_value(), "raw")
    with assert_raises():
        _ = response.json()["headers"]["X-Default"]


def test_binary_request_and_response() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var bytes = Bytes()
    for value in range(256):
        bytes.append(UInt8(value))
    var response = client.post("/echo-bytes", content=bytes.copy())
    assert_equal(response.content(), bytes)
    assert_equal(response.headers["Content-Type"], "application/octet-stream")
    var streamed = client.stream("POST", "/echo-bytes", content=bytes.copy())
    var received = Bytes()
    while True:
        var chunk = streamed.read_chunk(13)
        if not chunk:
            break
        for byte in chunk.value():
            received.append(byte)
    assert_equal(received, bytes)


def test_repeated_headers_on_wire() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get(
        "/echo-headers",
        headers=Headers(
            List[Tuple[String, String]](
                [
                    ("X-Repeated", "first"),
                    ("X-Repeated", "second"),
                ]
            )
        ),
    )
    assert_equal(response.json()["values"][0].string_value(), "first")
    assert_equal(response.json()["values"][1].string_value(), "second")


comptime TEST_FUNCTIONS = __functions_in_module()
