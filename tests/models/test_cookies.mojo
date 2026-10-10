"""Cookies tests."""
from req import CookieJar, Headers, URL
from req._cookies import CookieJar
from std.testing import assert_equal, assert_true


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
