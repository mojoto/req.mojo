"""Pinned v0.28.1 scenarios adapted to the native synchronous API."""
from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from req import Client, Auth, Headers, Bytes, ErrorKind, encode_utf8
from req._utils import percent_encode


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


comptime TEST_FUNCTIONS = __functions_in_module()
