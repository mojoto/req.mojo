import req
from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from req import Headers, QueryParams, Auth, JSONValue, encode_utf8


def test_convenience_methods_and_bodies() raises:
    var url = getenv("REQ_TEST_URL") + "/echo"
    assert_equal(req.get(url).json()["method"].string_value(), "GET")
    assert_equal(len(req.head(url).content()), 0)
    assert_equal(
        req.post(url, content=encode_utf8("raw")).json()["body"].string_value(),
        "raw",
    )
    assert_equal(req.put(url).json()["method"].string_value(), "PUT")
    assert_equal(req.patch(url).json()["method"].string_value(), "PATCH")
    assert_equal(req.delete(url).json()["method"].string_value(), "DELETE")
    assert_equal(req.options(url).json()["method"].string_value(), "OPTIONS")
    var response = req.post(
        url,
        data=QueryParams("a=hello+world&a=two"),
        auth=Auth.basic("user", "pass"),
    )
    assert_equal(response.json()["body"].string_value(), "a=hello+world&a=two")
    assert_equal(
        response.json()["headers"]["Authorization"].string_value(),
        "Basic dXNlcjpwYXNz",
    )
    with assert_raises():
        _ = req.post(url, content=encode_utf8("x"), json=JSONValue.null())


def test_top_level_session_isolation_and_status() raises:
    _ = req.get(getenv("REQ_TEST_URL") + "/cookies/set")
    var response = req.get(getenv("REQ_TEST_URL") + "/cookies/check")
    with assert_raises():
        _ = response.json()["headers"]["Cookie"]
    for status in [200, 300, 404, 500]:
        var result = req.get(
            getenv("REQ_TEST_URL") + "/status/" + String(status)
        )
        assert_equal(result.status_code, status)
        if status >= 400:
            with assert_raises():
                result.raise_for_status()
        else:
            result.raise_for_status()
    var empty = req.get(getenv("REQ_TEST_URL") + "/empty")
    assert_equal(empty.status_code, 204)
    with assert_raises():
        _ = empty.json()
    var invalid = req.get(getenv("REQ_TEST_URL") + "/invalid-utf8")
    with assert_raises():
        _ = invalid.text()


comptime TEST_FUNCTIONS = __functions_in_module()
