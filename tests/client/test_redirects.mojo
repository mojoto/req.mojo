"""Redirects tests."""
from req import (
    Auth,
    Bytes,
    Client,
    ErrorKind,
    Headers,
    QueryParams,
    URL,
    encode_utf8,
)
from req._utils import percent_encode
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def test_redirect_methods_and_defaults() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var first = client.get("/redirect")
    assert_equal(first.status_code, 302)
    assert_true(first.is_redirect())
    for code in [301, 302, 303, 307, 308]:
        var response = client.post(
            "/redirect?code=" + String(code),
            content=encode_utf8("payload"),
            headers=Headers({"Content-Type": "text/plain"}),
            follow_redirects=True,
        )
        var result = response.json()
        assert_equal(
            result["method"].string_value(), "POST" if code >= 307 else "GET"
        )
        assert_equal(
            result["body"].string_value(), "payload" if code >= 307 else ""
        )
        assert_equal(response.url.path(), "/echo")
        if code < 307:
            with assert_raises():
                _ = result["headers"]["Content-Type"]
    var response = client.put(
        "/redirect?code=302", content=encode_utf8("keep"), follow_redirects=True
    )
    assert_equal(response.json()["method"].string_value(), "PUT")
    assert_equal(response.json()["body"].string_value(), "keep")


def test_redirect_origin_and_limits() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        auth=Auth.bearer("secret"),
        follow_redirects=True,
        max_redirects=2,
    )
    var target = percent_encode(getenv("REQ_TEST_OTHER_URL") + "/echo")
    var response = client.get(
        "/redirect?to=" + target,
        headers=Headers(
            {"Cookie": "secret=yes", "Proxy-Authorization": "secret"}
        ),
    )
    for key in ["Authorization", "Proxy-Authorization", "Cookie"]:
        with assert_raises():
            _ = response.json()["headers"][key]
    with assert_raises():
        _ = client.get("/loop")
    var none = Client(
        base_url=getenv("REQ_TEST_URL"), follow_redirects=True, max_redirects=0
    )
    with assert_raises():
        _ = none.get("/redirect")


def test_binary_upload_replays_307_and_308() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var body = Bytes(capacity=65537)
    for i in range(65537):
        body.append(UInt8(i % 251))
    var next = percent_encode("/redirect?code=308&to=/echo-bytes")
    var response = client.post(
        "/redirect?code=307&to=" + next, content=body.copy()
    )
    assert_equal(response.content(), body)
    assert_equal(response.request.content.value(), body)
    assert_equal(response.request.method, "POST")
    assert_equal(response.url.path(), "/echo-bytes")


def test_redirect_cookie_selection_and_request_edits() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    client.cookies.set("scoped", "yes", domain="127.0.0.1", path="/redirect")
    var response = client.get("/redirect?to=/echo")
    with assert_raises():
        _ = response.json()["headers"]["Cookie"]
    var request = client.build_request("GET", "/redirect?to=/echo")
    request.headers.set("Cookie", "explicit=edited")
    var edited = client.send(request)
    assert_equal(
        edited.json()["headers"]["Cookie"].string_value(), "explicit=edited"
    )


def test_redirect_method_and_body_matrix() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for method in ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]:
        for code in [301, 302, 303, 307, 308]:
            for with_body in [False, True]:
                if method == "HEAD" and with_body:
                    continue
                var body: Optional[Bytes] = None
                var headers = Headers()
                if with_body:
                    body = encode_utf8("test 123")
                    headers.set("Content-Type", "text/plain")
                var response = client.stream(
                    method,
                    "/redirect?code=" + String(code),
                    content=body,
                    headers=headers,
                    follow_redirects=True,
                )
                var drops_body = (code == 303 and method != "HEAD") or (
                    code in [301, 302] and method == "POST"
                )
                assert_equal(response.status_code, 200)
                assert_equal(
                    response.request.method, "GET" if drops_body else method
                )
                assert_equal(response.url.path(), "/echo")
                _ = response.read()
                if method == "HEAD":
                    assert_equal(response.content(), Bytes())
                else:
                    assert_equal(
                        response.json()["method"].string_value(),
                        "GET" if drops_body else method,
                    )
                    assert_equal(
                        response.json()["body"].string_value(),
                        "test 123" if with_body and not drops_body else "",
                    )
                if drops_body:
                    assert_true(not response.request.content)
                    assert_true("Content-Type" not in response.request.headers)
                elif with_body:
                    assert_equal(
                        response.request.content.value(),
                        encode_utf8("test 123"),
                    )


def test_redirect_hostname_updates_host_and_credentials() raises:
    var source = getenv("REQ_TEST_URL")
    var target = source.replace("127.0.0.1", "localhost") + "/echo"
    var client = Client(base_url=source, follow_redirects=True)
    var headers = Headers(
        {
            "Host": "example.com",
            "Authorization": "secret",
            "Proxy-Authorization": "secret",
            "Cookie": "explicit=secret",
        }
    )
    var response = client.get(
        "/redirect?to="
        + String(QueryParams({"to": target})).removeprefix("to="),
        headers=headers,
    )
    assert_equal(String(response.url), target)
    assert_equal(
        response.json()["headers"]["Host"].string_value(),
        "localhost:" + String(URL(source).port()),
    )
    for name in ["Authorization", "Proxy-Authorization", "Cookie"]:
        assert_true(name not in response.request.headers)


def test_redirect_301() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/redirect?code=301",
        content=encode_utf8("Example request body"),
        follow_redirects=True,
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.request.method, "GET")
    assert_equal(response.json()["body"].string_value(), "")


def test_redirect_302() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/redirect?code=302",
        content=encode_utf8("Example request body"),
        follow_redirects=True,
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.request.method, "GET")
    assert_equal(response.json()["body"].string_value(), "")


def test_redirect_303() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/redirect?code=303",
        content=encode_utf8("Example request body"),
        follow_redirects=True,
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.request.method, "GET")
    assert_equal(response.json()["body"].string_value(), "")


def test_redirect_307() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/redirect?code=307",
        content=encode_utf8("Example request body"),
        follow_redirects=True,
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.request.method, "POST")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_redirect_308() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/redirect?code=308",
        content=encode_utf8("Example request body"),
        follow_redirects=True,
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.request.method, "POST")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_head_redirect() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for code in [301, 302, 303, 307, 308]:
        var response = client.head(
            "/redirect?code=" + String(code), follow_redirects=True
        )
        assert_equal(response.status_code, 200)
        assert_equal(response.request.method, "HEAD")
        assert_equal(response.content(), Bytes())


def test_redirect_relative() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.get("/redirect?to=" + percent_encode("/echo"))
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.json()["path"].string_value(), "/echo")


def test_redirect_dotted() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.get("/redirect?to=" + percent_encode("../echo"))
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.json()["path"].string_value(), "/echo")


def test_redirect_fragment() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.get(
        "/redirect?to=" + percent_encode("/echo#fragment")
    )
    assert_equal(response.url.path(), "/echo")
    assert_equal(response.json()["path"].string_value(), "/echo")


def test_redirect_encoded() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.get(
        "/redirect?to=" + percent_encode("/snow/%E9%9B%AA")
    )
    assert_equal(response.url.path(), "/snow/%E9%9B%AA")
    assert_equal(response.json()["path"].string_value(), "/snow/%E9%9B%AA")


def test_scheme_relative() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var authority = getenv("REQ_TEST_OTHER_URL").removeprefix("http:")
    var response = client.get(
        "/redirect?to=" + percent_encode(String(authority) + "/echo")
    )
    assert_equal(String(response.url), getenv("REQ_TEST_OTHER_URL") + "/echo")


def test_redirect_limit_exact() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), follow_redirects=True, max_redirects=20
    )
    var response = client.get("/redirect-chain?count=20")
    assert_equal(response.status_code, 200)
    assert_equal(response.text(), "finished")
    assert_equal(response.url.query(), "count=0")


def test_redirect_limit() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), follow_redirects=True, max_redirects=20
    )
    var caught = False
    try:
        _ = client.get("/redirect-chain?count=21")
    except error:
        assert_equal(error.kind, ErrorKind.TooManyRedirects)
        assert_equal(error.method.value(), "GET")
        assert_true(Bool(error.url))
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").status_code, 200)


def test_redirect_loop() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), follow_redirects=True, max_redirects=20
    )
    var caught = False
    try:
        _ = client.get("/loop")
    except error:
        assert_equal(error.kind, ErrorKind.TooManyRedirects)
        assert_equal(error.method.value(), "GET")
        assert_true(Bool(error.url))
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").status_code, 200)


def test_redirect_override() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.get("/redirect", follow_redirects=False)
    assert_equal(response.status_code, 302)
    assert_equal(response.url.path(), "/redirect")
    response = client.get("/redirect")
    assert_equal(response.status_code, 200)


def test_cross_origin_auth() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        auth=Auth.basic("user", "password"),
        follow_redirects=True,
    )
    var target = getenv("REQ_TEST_OTHER_URL") + "/echo"
    var response = client.get(
        "/redirect?to=" + percent_encode(target),
    )
    assert_equal(String(response.url), target)
    with assert_raises():
        _ = response.json()["headers"]["Authorization"]
    assert_true(
        response.json()["headers"]["Host"].string_value() != "wrong.example"
    )


def test_cross_origin_header() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        auth=Auth.basic("user", "password"),
        follow_redirects=True,
    )
    var target = getenv("REQ_TEST_OTHER_URL") + "/echo"
    var response = client.get(
        "/redirect?to=" + percent_encode(target),
        headers=Headers({"Authorization": "secret", "Host": "wrong.example"}),
    )
    assert_equal(String(response.url), target)
    with assert_raises():
        _ = response.json()["headers"]["Authorization"]
    assert_true(
        response.json()["headers"]["Host"].string_value() != "wrong.example"
    )


def test_same_origin_auth() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.get(
        "/redirect", headers=Headers({"Authorization": "secret"})
    )
    assert_equal(
        response.json()["headers"]["Authorization"].string_value(), "secret"
    )


def test_cross_origin_tls_auth() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        ca_file=getenv("REQ_TEST_CA_FILE"),
        follow_redirects=True,
    )
    var target = getenv("REQ_TEST_TLS_URL") + "/echo"
    var response = client.get(
        "/redirect?to=" + percent_encode(target),
        headers=Headers({"Authorization": "secret"}),
    )
    assert_equal(String(response.url), target)
    with assert_raises():
        _ = response.json()["headers"]["Authorization"]


def test_no_body_redirect() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.post(
        "/redirect?code=303",
        content=encode_utf8("test 123"),
        headers=Headers(
            {
                "Content-Type": "custom",
                "Content-Length": "8",
                "Content-Encoding": "identity",
            }
        ),
    )
    assert_equal(response.request.method, "GET")
    assert_true(not response.request.content)
    for name in ["Content-Type", "Content-Encoding", "Content-Length"]:
        assert_true(name not in response.request.headers)
    assert_equal(response.json()["body"].string_value(), "")


def test_stream_no_redirect() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/redirect", follow_redirects=False)
    assert_equal(response.status_code, 302)
    assert_equal(response.headers["Location"], "/echo")
    response.close()
    assert_true(response.is_closed())


def test_cookie_redirect() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var login = client.get("/redirect-cookie")
    assert_equal(
        login.json()["headers"]["Cookie"].string_value(), "session=active"
    )
    assert_equal(
        client.cookies.get("session", domain="127.0.0.1").value(), "active"
    )
    var logout = client.get("/redirect-cookie?delete=1")
    with assert_raises():
        _ = logout.json()["headers"]["Cookie"]
    assert_true(not client.cookies.get("session", domain="127.0.0.1"))


def test_redirect_invalid() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var caught = False
    try:
        _ = client.get("/redirect?to=" + percent_encode("http://[xyz]/"))
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").status_code, 200)


def test_redirect_custom_scheme() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var caught = False
    try:
        _ = client.get(
            "/redirect?to=" + percent_encode("market://details?id=42")
        )
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").status_code, 200)


def test_redirect_malformed() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var caught = False
    try:
        _ = client.get("/redirect?to=" + percent_encode("https://:443/"))
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").status_code, 200)
