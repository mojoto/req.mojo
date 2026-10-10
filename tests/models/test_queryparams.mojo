"""Queryparams tests."""
from req import QueryParams
from req._types import StringPairs
from std.testing import assert_equal, assert_true


def test_queryparams_pair_constructor() raises:
    var params = QueryParams(
        List[Tuple[String, String]](
            [
                ("a", "123"),
                ("a", "456"),
                ("b", "789"),
            ]
        )
    )
    assert_equal(params.get_all("a"), List[String](["123", "456"]))
    assert_equal(params["b"], "789")
    assert_equal(String(params), "a=123&a=456&b=789")
    assert_equal(QueryParams({"a": "123"})["a"], "123")


def test_queryparams_repeated_values() raises:
    var p = QueryParams("a=123&a=456&b=789")
    assert_true("a" in p and "A" not in p and "c" not in p)
    assert_equal(p["a"], "123")
    assert_true(not p.get("missing"))
    assert_equal(p.get_all("a"), List[String](["123", "456"]))
    assert_equal(len(p), 3)
    assert_equal(String(p), "a=123&a=456&b=789")
    var pairs = p.items()
    pairs[0] = ("a", "changed")
    assert_equal(p["a"], "123")


def test_params_set() raises:
    var p = QueryParams("a=123&a=456&b=789")
    p.set("a", "000")
    assert_equal(String(p), "a=000&b=789")


def test_params_add() raises:
    var p = QueryParams("a=123")
    p.add("a", "456")
    assert_equal(String(p), "a=123&a=456")


def test_params_remove() raises:
    var p = QueryParams("a=123&a=456&b=789")
    p.remove("a")
    p.remove("missing")
    assert_equal(String(p), "b=789")


def test_params_merge() raises:
    var p = QueryParams("a=123")
    p.merge(QueryParams("b=456"))
    assert_equal(String(p), "a=123&b=456")
    p.merge(QueryParams("a=000&c=789"))
    assert_equal(p["a"], "000")
    assert_equal(p["b"], "456")
    assert_equal(p["c"], "789")


def test_params_copy() raises:
    var p = QueryParams("a=123")
    var copied = p
    copied.set("a", "changed")
    assert_equal(p["a"], "123")


def test_params_empty_separators() raises:
    var p = QueryParams("a=1&&b=2&")
    assert_equal(
        p.items(), List[Tuple[String, String]]([("a", "1"), ("b", "2")])
    )
    assert_equal(len(QueryParams("&&")), 0)
    assert_equal(QueryParams("=empty")[""], "empty")


def test_empty_query_params_variants() raises:
    for query in ["a=", "a"]:
        assert_equal(String(QueryParams(query)), "a=")
    assert_equal(String(QueryParams("")), "")


def queryparams(source: String) raises:
    var params = QueryParams(source)
    if source == "pairs":
        params = QueryParams(
            List[Tuple[String, String]](
                [("a", "123"), ("a", "456"), ("b", "789")]
            )
        )
    assert_true("a" in params and "A" not in params and "c" not in params)
    assert_equal(params["a"], "123")
    assert_equal(params.get("a").value(), "123")
    assert_true(not params.get("missing"))
    assert_equal(params.get_all("a"), List[String](["123", "456"]))
    assert_equal(len(params), 3)
    assert_equal(String(params), "a=123&a=456&b=789")
    var pairs = params.items()
    assert_equal(
        pairs,
        List[Tuple[String, String]]([("a", "123"), ("a", "456"), ("b", "789")]),
    )
    pairs[0] = ("a", "changed")
    assert_equal(params["a"], "123")


def test_queryparams_parameters() raises:
    queryparams("a=123&a=456&b=789")
    queryparams("pairs")


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
