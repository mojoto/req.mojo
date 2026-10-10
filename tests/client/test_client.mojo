"""Client tests."""
import req
from req import (
    Auth,
    Bytes,
    Client,
    ErrorKind,
    HTTPError,
    Headers,
    JSONValue,
    QueryParams,
    Request,
    URL,
    encode_utf8,
)
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def test_build_request_merge() raises:
    var headers = Headers({"X-Default": "yes", "X-Override": "old"})
    var client = Client(
        base_url=getenv("REQ_TEST_URL") + "/v1/",
        headers=headers,
        params=QueryParams("a=client&b=default"),
        auth=Auth.bearer("token"),
    )
    headers.set("X-Default", "changed")
    var request = client.build_request(
        "GET",
        "users?a=url&c=keep",
        headers=Headers({"x-override": "new"}),
        params=QueryParams("a=one&a=two"),
    )
    assert_equal(request.url.path(), "/v1/users")
    assert_equal(request.url.query(), "c=keep&b=default&a=one&a=two")
    assert_equal(request.headers["X-Default"], "yes")
    assert_equal(request.headers["X-Override"], "new")
    assert_equal(request.headers["Authorization"], "Bearer token")
    assert_true(
        "Authorization"
        not in client.build_request("GET", getenv("REQ_TEST_OTHER_URL")).headers
    )
    assert_true(
        "Authorization"
        not in client.build_request("GET", "users", auth=Auth.none()).headers
    )
    client.close()
    client.close()
    with assert_raises():
        _ = client.build_request("GET", "users")


def test_client_requests_and_reuse() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), headers=Headers({"X-Default": "yes"})
    )
    var first = client.get("/echo")
    var second = client.post("/echo", json=JSONValue.null())
    assert_equal(
        first.json()["connection"].int_value(),
        second.json()["connection"].int_value(),
    )
    assert_equal(second.json()["body"].string_value(), "null")
    assert_equal(
        second.json()["headers"]["Content-Type"].string_value(),
        "application/json",
    )
    var raw = client.send(Request("GET", getenv("REQ_TEST_URL") + "/echo"))
    with assert_raises():
        _ = raw.json()["headers"]["X-Default"]
    var path = client.get(getenv("REQ_TEST_URL") + "/one/../echo")
    assert_equal(path.json()["path"].string_value(), "/one/../echo")
    client.close()
    assert_equal(first.json()["method"].string_value(), "GET")
    with assert_raises():
        _ = client.get("/echo")


def test_client_cookie_session() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    _ = client.get("/cookies/set")
    assert_equal(client.cookies.get("a", domain="127.0.0.1").value(), "one")
    var response = client.get("/cookies/check")
    assert_equal(
        response.json()["headers"]["Cookie"].string_value(), "b=two; a=one"
    )
    response = client.get("/echo", headers=Headers({"Cookie": "explicit=yes"}))
    assert_equal(
        response.json()["headers"]["Cookie"].string_value(), "explicit=yes"
    )


def test_request_upload_copy_isolation() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var expected = Bytes(capacity=65537)
    for i in range(65537):
        expected.append(UInt8(i % 251))
    var input: Optional[Bytes] = expected.copy()
    var request = client.build_request("post", "/echo-bytes", content=input)
    input.value()[0] = 255
    var response = client.send(request, stream=True)
    request.content.value()[1] = 255
    assert_equal(response.read(), expected)
    assert_equal(response.request.content.value(), expected)
    var again = client.send(request)
    assert_equal(again.content(), request.content.value())
    var snapshot = input.value().copy()
    var direct = client.stream("POST", "/echo-bytes", content=input)
    input.value()[2] = 255
    assert_equal(direct.read(), snapshot)
    assert_equal(direct.request.content.value(), snapshot)


def test_build_request_parsed_url_matches_public_constructor() raises:
    var client = Client()
    for text in [
        "https://EXAMPLE.com:443/a b/雪?x=%2f#fragment",
        "http://[::1]:8080/a/../b?repeat=1&repeat=2",
        "http://example.com/a;:@!$&'()*+,=-._~/0?value=ok",
    ]:
        var built = client.build_request("get", text)
        var public = Request("get", text)
        assert_equal(String(built.url), String(public.url))
        assert_equal(built.method, public.method)
    with assert_raises():
        _ = client.build_request("GET\n", "http://example.com")
    with assert_raises():
        _ = client.build_request(
            "HEAD", "http://example.com", content=encode_utf8("body")
        )
    with assert_raises():
        _ = client.build_request("GET", "http://example.com/%GG")


def test_client_context() raises:
    var owner = Client(base_url=getenv("REQ_TEST_URL"))
    with owner.context() as client:
        _ = client.get("/echo")
        client.cookies().set("test", "yes", domain="127.0.0.1")
    assert_true(owner.is_closed())
    assert_equal(owner.cookies.get("test", domain="127.0.0.1").value(), "yes")
    with assert_raises():
        _ = owner.context()


def _typed_context_failure(mut owner: Client) raises HTTPError:
    with owner.context() as client:
        _ = client.build_request("GET", "/echo")
        raise HTTPError(ErrorKind.InvalidRequest, "original context error")


def test_context_preserves_typed_error() raises:
    var owner = Client(base_url=getenv("REQ_TEST_URL"))
    var caught = False
    try:
        _typed_context_failure(owner)
    except error:
        assert_equal(error.kind, ErrorKind.InvalidRequest)
        assert_equal(error.message, "original context error")
        caught = True
    assert_true(caught)
    assert_true(owner.is_closed())


def test_client_invalid_url_variants() raises:
    var client = Client()
    for url in ["invalid://example.com", "://example.com", "http://"]:
        var caught = False
        try:
            _ = client.get(url)
        except error:
            assert_equal(error.kind, ErrorKind.InvalidURL)
            caught = True
        assert_true(caught, url)


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


def invalid_client_url(text: String) raises:
    var client = Client()
    var caught = False
    try:
        _ = client.get(text)
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught, text)


def test_invalid_client_url_parameters() raises:
    invalid_client_url("://example.com")
    invalid_client_url("http://")
    invalid_client_url("invalid://example.com")
