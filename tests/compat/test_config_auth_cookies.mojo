"""Pinned v0.28.1 scenarios adapted to the native synchronous API."""
from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from req import Client, CookieJar, URL, Headers, Auth, Timeout, ErrorKind
from std.math import inf, nan


def test_timeout_default() raises:
    var timeout = Timeout()
    timeout.validate()
    assert_equal(timeout.connect.value(), Float64(5.0))
    assert_equal(timeout.read.value(), Float64(5.0))
    assert_equal(timeout.write.value(), Float64(5.0))


def test_timeout_single() raises:
    var timeout = Timeout(10.0)
    timeout.validate()
    assert_equal(timeout.connect.value(), Float64(10.0))
    assert_equal(timeout.read.value(), Float64(10.0))
    assert_equal(timeout.write.value(), Float64(10.0))


def test_timeout_all() raises:
    var timeout = Timeout(connect=1.0, read=2.0, write=3.0)
    timeout.validate()
    assert_equal(timeout.connect.value(), Float64(1.0))
    assert_equal(timeout.read.value(), Float64(2.0))
    assert_equal(timeout.write.value(), Float64(3.0))


def test_timeout_disabled() raises:
    var timeout = Timeout.disabled()
    timeout.validate()
    assert_true(not timeout.connect)
    assert_true(not timeout.read)
    assert_true(not timeout.write)


def test_timeout_partial() raises:
    var timeout = Timeout(connect=None, read=2.0, write=None)
    timeout.validate()
    assert_true(not timeout.connect)
    assert_equal(timeout.read.value(), Float64(2.0))
    assert_true(not timeout.write)


def test_timeout_copy() raises:
    var original = Timeout(10.0)
    var copy = original
    copy.read = 2.0
    assert_equal(original.read.value(), Float64(10.0))
    assert_equal(copy.read.value(), Float64(2.0))


def test_timeout_invalid() raises:
    for value in [
        Float64(0),
        Float64(-1),
        inf[DType.float64](),
        -inf[DType.float64](),
        nan[DType.float64](),
    ]:
        with assert_raises():
            _ = Timeout(value)
    var mutated = Timeout()
    mutated.read = -1.0
    with assert_raises():
        mutated.validate()
    with assert_raises():
        _ = Client(timeout=mutated)


def test_basic_normal() raises:
    var headers = Headers()
    Auth.basic("username", "password").apply(headers)
    assert_equal(headers["Authorization"], "Basic dXNlcm5hbWU6cGFzc3dvcmQ=")


def test_basic_empty() raises:
    var headers = Headers()
    Auth.basic("", "").apply(headers)
    assert_equal(headers["Authorization"], "Basic Og==")


def test_basic_colon_password() raises:
    var headers = Headers()
    Auth.basic("user", "a:b").apply(headers)
    assert_equal(headers["Authorization"], "Basic dXNlcjphOmI=")


def test_basic_unicode() raises:
    var headers = Headers()
    Auth.basic("é", "雪").apply(headers)
    assert_equal(headers["Authorization"], "Basic w6k66Zuq")


def test_basic_client() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), auth=Auth.basic("username", "password")
    )
    var response = client.get("/echo")
    assert_equal(
        response.json()["headers"]["Authorization"].string_value(),
        "Basic dXNlcm5hbWU6cGFzc3dvcmQ=",
    )


def test_basic_stream() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream(
        "GET", "/echo", auth=Auth.basic("username", "password")
    )
    _ = response.read()
    assert_equal(
        response.json()["headers"]["Authorization"].string_value(),
        "Basic dXNlcm5hbWU6cGFzc3dvcmQ=",
    )


def test_auth_disabled() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), auth=Auth.basic("user", "password")
    )
    var response = client.get("/echo", auth=Auth.none())
    with assert_raises():
        _ = response.json()["headers"]["Authorization"]
    var next = client.get("/echo")
    assert_equal(
        next.json()["headers"]["Authorization"].string_value(),
        "Basic dXNlcjpwYXNzd29yZA==",
    )


def test_auth_override() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), auth=Auth.basic("user", "password")
    )
    var request = client.build_request(
        "GET", "/echo", auth=Auth.bearer("override")
    )
    assert_equal(request.headers["Authorization"], "Bearer override")
    request = client.build_request(
        "GET",
        "/echo",
        headers=Headers({"authorization": "explicit"}),
        auth=Auth.bearer("override"),
    )
    assert_equal(request.headers["Authorization"], "explicit")


def test_auth_invalid() raises:
    with assert_raises():
        _ = Auth.basic("user:name", "password")
    for value in ["", "space token", "a\n", "a\r", "a\t", "雪"]:
        with assert_raises():
            _ = Auth.bearer(value)


def test_tls_no_verify() raises:
    var client = Client(verify=False)
    assert_equal(
        client.get(getenv("REQ_TEST_TLS_URL") + "/echo").status_code, 200
    )


def test_tls_ca() raises:
    var client = Client(ca_file=getenv("REQ_TEST_CA_FILE"))
    assert_equal(
        client.get(getenv("REQ_TEST_TLS_URL") + "/echo").status_code, 200
    )


def test_tls_missing_ca() raises:
    var client = Client(ca_file=getenv("REQ_TEST_CA_FILE") + ".missing")
    var caught = False
    try:
        _ = client.get(getenv("REQ_TEST_TLS_URL") + "/echo")
    except error:
        assert_equal(error.kind, ErrorKind.TLSError)
        caught = True
    assert_true(caught)


def test_cookies() raises:
    var jar = CookieJar()
    jar.set("name", "value", domain="example.com")
    assert_equal(jar.get("name", domain="example.com").value(), "value")
    jar.delete("name", domain="example.com")
    assert_true(not jar.get("name", domain="example.com"))
    assert_true(not jar.header(URL("https://example.com/")))


def test_cookies_domains() raises:
    var jar = CookieJar()
    jar.set("name", "one", domain="example.com")
    jar.set("name", "two", domain="other.example.com")
    assert_equal(jar.get("name", domain="example.com").value(), "one")
    assert_equal(jar.get("name", domain="other.example.com").value(), "two")
    jar.delete("name", domain="example.com")
    assert_equal(
        jar.header(URL("https://other.example.com/")).value(), "name=two"
    )
    assert_true(not jar.header(URL("https://example.com/")))


def test_cookies_paths() raises:
    var jar = CookieJar()
    jar.set("name", "one", domain="example.com", path="/subpath/1")
    jar.set("name", "two", domain="example.com", path="/subpath/2")
    assert_equal(
        jar.header(URL("https://example.com/subpath/1")).value(), "name=one"
    )
    assert_equal(
        jar.header(URL("https://example.com/subpath/2")).value(), "name=two"
    )
    jar.delete("name", domain="example.com", path="/subpath/1")
    assert_true(not jar.header(URL("https://example.com/subpath/1")))
    jar.delete("name", domain="example.com", path="/subpath/2")
    assert_true(not jar.header(URL("https://example.com/subpath/2")))


def test_cookies_multiple_set() raises:
    var jar = CookieJar()
    var headers = Headers(
        List[Tuple[String, String]](
            [
                (
                    "Set-Cookie",
                    (
                        "a=one; Expires=Tue, 08 Sep 2099 18:33:35 GMT; Path=/;"
                        " Domain=.example.com; Secure"
                    ),
                ),
                (
                    "Set-Cookie",
                    (
                        "b=two=three; Expires=Mon, 08 Feb 2099 18:33:35 GMT;"
                        " Path=/; Domain=.example.com; HttpOnly"
                    ),
                ),
            ]
        )
    )
    jar.extract(headers, URL("https://www.example.com/"))
    assert_equal(
        jar.header(URL("https://www.example.com/")).value(),
        "a=one; b=two=three",
    )
    assert_equal(
        jar.header(URL("http://www.example.com/")).value(), "b=two=three"
    )


def test_cookie_copy() raises:
    var original = CookieJar()
    original.set("name", "value", domain="127.0.0.1")
    var client = Client(base_url=getenv("REQ_TEST_URL"), cookies=original)
    original.clear()
    assert_equal(
        client.cookies.get("name", domain="127.0.0.1").value(), "value"
    )
    var response = client.get("/echo")
    assert_equal(
        response.json()["headers"]["Cookie"].string_value(), "name=value"
    )


def test_cookie_persistence() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    _ = client.get("/cookies/set")
    assert_equal(client.cookies.get("a", domain="127.0.0.1").value(), "one")
    var response = client.get("/echo")
    assert_equal(response.json()["headers"]["Cookie"].string_value(), "a=one")


def test_cookie_default_path() raises:
    var jar = CookieJar()
    jar.extract(
        Headers({"Set-Cookie": "a=one"}), URL("https://example.com/api/login")
    )
    assert_equal(
        jar.header(URL("https://example.com/api/users")).value(), "a=one"
    )
    assert_true(not jar.header(URL("https://example.com/apix")))
    assert_true(not jar.header(URL("https://sub.example.com/api/users")))


def test_cookie_expiry_precedence() raises:
    var jar = CookieJar()
    jar.extract(
        Headers(
            {
                "Set-Cookie": (
                    "a=one; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Max-Age=3600"
                )
            }
        ),
        URL("https://example.com/"),
    )
    assert_equal(jar.get("a", domain="example.com").value(), "one")
    jar.extract(
        Headers(
            {
                "Set-Cookie": (
                    "a=gone; Expires=Tue, 08 Sep 2099 18:33:35 GMT; Max-Age=0"
                )
            }
        ),
        URL("https://example.com/"),
    )
    assert_true(not jar.header(URL("https://example.com/")))


def test_cookie_stable_order() raises:
    var jar = CookieJar()
    jar.set("first", "one", domain="example.com")
    jar.set("second", "two", domain="example.com")
    jar.set("scoped", "three", domain="example.com", path="/api")
    assert_equal(
        jar.header(URL("https://example.com/api/users")).value(),
        "scoped=three; first=one; second=two",
    )


def test_cookie_replace_order() raises:
    var jar = CookieJar()
    jar.set("first", "one", domain="example.com")
    jar.set("second", "two", domain="example.com")
    jar.set("first", "updated", domain="example.com")
    assert_equal(
        jar.header(URL("https://example.com/")).value(),
        "first=updated; second=two",
    )


def test_cookie_bad_domain_overwrite() raises:
    var jar = CookieJar()
    jar.extract(
        Headers(
            {
                "Set-Cookie": (
                    "session=secret; Domain=other.com; Domain=example.com"
                )
            }
        ),
        URL("https://example.com/"),
    )
    assert_true(not jar.header(URL("https://example.com/")))


def test_tls_hostname_mismatch() raises:
    var target = getenv("REQ_TEST_TLS_URL").replace("localhost", "127.0.0.1")
    var client = Client(ca_file=getenv("REQ_TEST_CA_FILE"))
    var caught = False
    try:
        _ = client.get(target + "/echo")
    except error:
        assert_equal(error.kind, ErrorKind.TLSError)
        caught = True
    assert_true(caught)


def test_expired_cookie_replacement_removes_only_matching_scope() raises:
    var jar = CookieJar()
    jar.set("first", "one", domain="example.com")
    jar.set("second", "two", domain="example.com")
    jar.set("first", "scoped", domain="example.com", path="/api")
    jar.set("first", "expired", domain="example.com", expires=0.0)
    assert_true(not jar.get("first", domain="example.com"))
    assert_equal(
        jar.get("first", domain="example.com", path="/api").value(), "scoped"
    )
    assert_equal(jar.get("second", domain="example.com").value(), "two")


def test_cookie_rejects_invalid_domain_attributes() raises:
    for value in [
        "a=one; Domain=other.com",
        "a=one; Domain=",
        "a=one; Domain=other.com; Domain=example.com",
        "a=one; Domain=example.com; Domain=other.com",
    ]:
        var jar = CookieJar()
        jar.extract(Headers({"Set-Cookie": value}), URL("https://example.com/"))
        assert_true(not jar.header(URL("https://example.com/")))


def test_expired_cookie_replacement_gets_new_creation_order() raises:
    var jar = CookieJar()
    jar.set("first", "one", domain="example.com")
    jar.set("second", "two", domain="example.com")
    jar._cookies[0].expires = 0.0
    jar.set("first", "updated", domain="example.com")
    assert_equal(
        jar.header(URL("https://example.com/")).value(),
        "second=two; first=updated",
    )


comptime TEST_FUNCTIONS = __functions_in_module()
