from std.testing import assert_equal, assert_true
from req import QueryParams
from req._types import StringPairs


def test_queryparams() raises:
    var q = QueryParams("a=123&a=456&b=789")
    assert_true("a" in q and "A" not in q)
    assert_equal(q["a"], "123")
    assert_equal(q.get_all("a"), List[String](["123", "456"]))
    assert_true(not q.get("missing"))
    assert_equal(String(q), "a=123&a=456&b=789")


def test_queryparam_mutations_and_merge() raises:
    var q = QueryParams({"a": "123"})
    q.add("a", "456")
    q.set("a", "789")
    assert_equal(String(q), "a=789")
    var pairs: StringPairs = [("a", "one"), ("a", "two"), ("b", "3")]
    q.merge(QueryParams(pairs))
    assert_equal(String(q), "a=one&a=two&b=3")
    q.remove("a")
    assert_equal(String(q), "b=3")


def test_empty_query_params() raises:
    assert_equal(String(QueryParams()), "")
    assert_equal(String(QueryParams("a")), "a=")
    assert_equal(String(QueryParams("a=")), "a=")
    var q = QueryParams({"a b": "x+y 雪"})
    assert_equal(q.encode(), "a%20b=x%2By%20%E9%9B%AA")
    assert_equal(q.encode(form=True), "a+b=x%2By+%E9%9B%AA")


comptime TEST_FUNCTIONS = __functions_in_module()
