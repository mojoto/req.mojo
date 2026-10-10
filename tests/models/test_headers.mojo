from std.testing import assert_equal, assert_true, assert_raises
from req import Headers
from req._types import StringPairs


def test_headers() raises:
    var pairs: StringPairs = [("a", "123"), ("A", "456"), ("b", "789")]
    var h = Headers(pairs)
    assert_true("a" in h and "A" in h)
    assert_true("c" not in h)
    assert_equal(h["A"], "123")
    assert_equal(h.get_all("a"), List[String](["123", "456"]))
    assert_true(not h.get("missing"))
    assert_equal(len(h.items()), 3)


def test_header_mutations() raises:
    var h = Headers({"a": "1", "b": "2"})
    h.add("A", "3")
    h.set("a", "4")
    assert_equal(h.get_all("A"), List[String](["4"]))
    assert_equal(h.items()[0][0], "a")
    h.remove("A")
    assert_true("a" not in h)


def test_headers_copy_and_multivalue_merge() raises:
    var original = Headers({"X-Default": "original"})
    var copied = original
    copied.set("x-default", "changed")
    assert_equal(original["x-default"], "original")
    var pairs: StringPairs = [("x-default", "one"), ("X-Default", "two")]
    original.merge(Headers(pairs))
    assert_equal(original.get_all("x-default"), List[String](["one", "two"]))
    var cookie_pairs: StringPairs = [
        ("Set-Cookie", "a=1"),
        ("Set-Cookie", "b=2"),
    ]
    var cookies = Headers(cookie_pairs)
    assert_equal(cookies.get_all("set-cookie"), List[String](["a=1", "b=2"]))


def test_invalid_headers() raises:
    for name in ["", "a b", "a:b", "snow雪"]:
        with assert_raises():
            _ = Headers({name: "value"})
    for value in ["hello\rworld", "hello\nworld", "hello\x00world"]:
        with assert_raises():
            _ = Headers({"a": value})


def test_header_name_comparison_boundaries() raises:
    var names = [
        "Key",
        "!#$%&'*+-.^_`|~",
        "^",
        "~",
        "X-Long-Header-Name-With-Mixed-CASE",
        "AAAAAAAAAAAAAAA^AAAAAAAAAAAAAAAAA",
        "AAAAAAAAAAAAAAA~AAAAAAAAAAAAAAAAA",
    ]
    var queries = [
        "key",
        "KEY",
        "Key",
        "!#$%&'*+-.^_`|~",
        "^",
        "~",
        "x-long-header-name-with-mixed-case",
        "X-LONG-HEADER-NAME-WITH-MIXED-CASE",
        "x-long-header-name-with-mixed-cas!",
        "x-long-header-name-with-mixed-雪",
        "aaaaaaaaaaaaaaa^aaaaaaaaaaaaaaaaa",
        "aaaaaaaaaaaaaaa~aaaaaaaaaaaaaaaaa",
        "",
        "absent",
    ]
    for name in names:
        var headers = Headers({name: "value"})
        for query in queries:
            assert_equal(query in headers, name.lower() == query.lower())
    for length in [1, 15, 16, 17, 31, 32, 33, 63, 64, 65]:
        var name = String()
        for _ in range(length):
            name += "A"
        var headers = Headers({name: "value"})
        assert_equal(headers[name.lower()], "value")
        var different = name.lower()
        different += "a"
        assert_true(different not in headers)
    var headers = Headers({"Key": "value"})
    headers.remove("Key")
    assert_equal(
        len(headers), 0 if String("Key").lower() == String("Key").lower() else 1
    )


comptime TEST_FUNCTIONS = __functions_in_module()
