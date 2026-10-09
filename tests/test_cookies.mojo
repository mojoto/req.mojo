from std.testing import assert_equal, assert_true
from req._cookies import CookieJar
from req import URL, Headers


def test_cookie_scopes() raises:
    var jar = CookieJar()
    jar.set("session", "root", domain="example.com")
    jar.set("session", "api", domain="example.com", path="/api")
    jar.set("secret", "yes", domain="example.com", secure=True)
    assert_equal(
        jar.header(URL("http://sub.example.com/api/users")).value(),
        "session=api; session=root",
    )
    assert_equal(
        jar.header(URL("http://example.com/apix")).value(), "session=root"
    )
    assert_true(not jar.header(URL("http://badexample.com")))
    assert_equal(
        jar.header(URL("http://1node.example.com")).value(), "session=root"
    )
    assert_true(not jar.header(URL("http://127.0.0.1")))
    assert_equal(
        jar.get("session", domain="example.com", path="/api").value(), "api"
    )
    jar.delete("session", domain="example.com", path="/api")
    assert_true(not jar.get("session", domain="example.com", path="/api"))


def test_set_cookie_and_expiration() raises:
    var jar = CookieJar()
    var headers = Headers()
    headers.add("Set-Cookie", "a=1")
    headers.add("Set-Cookie", "b=2; Path=/; Domain=example.com")
    headers.add("Set-Cookie", "bad=1; Domain=other.com")
    headers.add(
        "Set-Cookie", "expired=1; Expires=Thu, 01 Jan 1970 00:00:00 GMT"
    )
    jar.extract(headers, URL("https://example.com/api/users"))
    assert_equal(
        jar.header(URL("https://example.com/api/items")).value(), "a=1; b=2"
    )
    assert_equal(
        jar.header(URL("https://sub.example.com/api/items")).value(), "b=2"
    )
    jar.extract(
        Headers(
            {"Set-Cookie": "b=gone; Max-Age=0; Path=/; Domain=example.com"}
        ),
        URL("https://example.com"),
    )
    assert_true(not jar.get("b", domain="example.com"))
    var copy = jar
    copy.clear()
    assert_true(Bool(jar.header(URL("https://example.com/api/items"))))


comptime TEST_FUNCTIONS = __functions_in_module()
