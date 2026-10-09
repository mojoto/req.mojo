from std.testing import TestSuite, assert_equal, assert_true, assert_raises
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
    var cookie_pairs: StringPairs = [("Set-Cookie", "a=1"), ("Set-Cookie", "b=2")]
    var cookies = Headers(cookie_pairs)
    assert_equal(cookies.get_all("set-cookie"), List[String](["a=1", "b=2"]))


def test_invalid_headers() raises:
    for name in ["", "a b", "a:b", "snow雪"]:
        with assert_raises():
            _ = Headers({name: "value"})
    for value in ["hello\rworld", "hello\nworld", "hello\x00world"]:
        with assert_raises():
            _ = Headers({"a": value})


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
