from std.testing import assert_equal, assert_raises
from req import URL, QueryParams
from req._urls import _url_component


def test_url_components() raises:
    var url = URL("HTTPS://EXAMPLE.COM:443/a b/雪?x=1#ignored")
    assert_equal(String(url), "https://example.com/a%20b/%E9%9B%AA?x=1")
    assert_equal(url.host(), "example.com")
    assert_equal(url.port(), 443)
    assert_equal(String(URL("http://[::1]:8080")), "http://[::1]:8080/")
    assert_equal(
        String(URL("http://example.com/?a=%2f")), "http://example.com/?a=%2f"
    )


def test_url_component_ascii_fast_path_boundaries() raises:
    var digits = String("0123456789ABCDEF")
    for code in range(128):
        var text = String(chr(code))
        if code < 32 or code in [37, 92, 127]:
            with assert_raises():
                _ = _url_component("prefix" + text + "suffix")
        else:
            var expected = text
            if code in [32, 34, 60, 62, 94, 96, 123, 124, 125]:
                expected = (
                    "%"
                    + String(digits[byte=code // 16])
                    + String(digits[byte=code % 16])
                )
            assert_equal(
                _url_component("prefix" + text + "suffix"),
                "prefix" + expected + "suffix",
            )
    assert_equal(_url_component("a%2fb%FF"), "a%2fb%FF")
    assert_equal(_url_component("ok雪"), "ok%E9%9B%AA")


def test_url_query_params() raises:
    var url = URL("https://example.com/?a=1&a=2")
    assert_equal(url.query_params().get_all("a"), List[String](["1", "2"]))
    assert_equal(
        String(url.with_query(QueryParams({"b": "a b"}))),
        "https://example.com/?b=a%20b",
    )


def test_rfc3986_resolution() raises:
    var url = URL("http://a/b/c/d;p?q")
    var cases: List[Tuple[String, String]] = [
        ("g", "http://a/b/c/g"),
        ("./g", "http://a/b/c/g"),
        ("/g", "http://a/g"),
        ("//g", "http://g/"),
        ("?y", "http://a/b/c/d;p?y"),
        ("#s", "http://a/b/c/d;p?q"),
        ("g?y#s", "http://a/b/c/g?y"),
        ("..", "http://a/b/"),
        ("../g", "http://a/b/g"),
        ("../../g", "http://a/g"),
        ("../../../g", "http://a/g"),
        ("g/./h", "http://a/b/c/g/h"),
        ("g/../h", "http://a/b/c/h"),
        ("g//h", "http://a/b/c/g//h"),
        ("", "http://a/b/c/d;p?q"),
    ]
    for pair in cases:
        assert_equal(String(url.resolve(pair[0])), pair[1])
    var base = URL("https://example.com/v1/")
    assert_equal(String(base.resolve("users")), "https://example.com/v1/users")
    assert_equal(String(base.resolve("/users")), "https://example.com/users")


def test_invalid_url() raises:
    for value in [
        "/relative",
        "ftp://example.com",
        "http:///a",
        "http://user:secret@example.com",
        "http://example.com:0",
        "http://example.com:65536",
        "http://example.com:",
        "http://[bad]/",
        "http://example.com/%GG",
        "http://example.com/a\n",
    ]:
        with assert_raises():
            _ = URL(value)


comptime TEST_FUNCTIONS = __functions_in_module()
