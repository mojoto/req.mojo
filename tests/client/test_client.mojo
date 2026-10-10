from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from req import (
    Client,
    Headers,
    QueryParams,
    Auth,
    Request,
    JSONValue,
    encode_utf8,
    HTTPError,
    ErrorKind,
    Bytes,
)


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


comptime TEST_FUNCTIONS = __functions_in_module()
