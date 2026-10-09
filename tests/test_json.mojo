from std.testing import assert_equal, assert_true, assert_raises
from req import JSONValue
from std.math import inf, nan


def test_json_parse() raises:
    var value = JSONValue.parse(
        '{"name":"Mojo","scores":[1,2],"active":true,"empty":null}'
    )
    assert_equal(value["name"].string_value(), "Mojo")
    assert_equal(value["scores"][1].int_value(), 2)
    assert_true(value["active"].bool_value())
    assert_true(value["empty"].is_null())


def test_json_build_and_copy() raises:
    var value = JSONValue.object()
    value.set("name", JSONValue("Mojo"))
    var array = JSONValue.array()
    array.append(JSONValue(42))
    value.set("items", array)
    var copied = value
    copied.set("name", JSONValue("changed"))
    assert_equal(value["name"].string_value(), "Mojo")
    assert_equal(JSONValue.parse(value.to_string())["items"][0].int_value(), 42)
    assert_equal(JSONValue.null().to_string(), "null")


def test_json_unicode_and_invalid_input() raises:
    assert_equal(JSONValue.parse('"\\uD83D\\uDD25"').string_value(), "🔥")
    for text in ["", "{", "[1,]", "NaN", "true trailing", '"\\uD800"']:
        with assert_raises():
            _ = JSONValue.parse(text)


def test_nonfinite_numbers_rejected() raises:
    for value in [inf[DType.float64](), nan[DType.float64]()]:
        with assert_raises():
            _ = JSONValue(value)


def test_number_conversion() raises:
    assert_equal(JSONValue(42).float_value(), 42.0)
    assert_equal(JSONValue.parse("-42").float_value(), -42.0)
    assert_equal(
        JSONValue.parse("9223372036854775808").float_value(),
        9223372036854775808.0,
    )
    assert_equal(JSONValue(Float64(1.5)).float_value(), 1.5)


comptime TEST_FUNCTIONS = __functions_in_module()
