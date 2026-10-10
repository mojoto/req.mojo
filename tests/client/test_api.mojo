"""API tests."""
import req
from req import Auth, Bytes, JSONValue, QueryParams, encode_utf8
from std.os import getenv
from std.testing import assert_equal, assert_raises


def test_api_get() raises:
    var response = req.get(getenv("REQ_TEST_URL") + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "GET")


def test_api_post() raises:
    var response = req.post(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "POST")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_options() raises:
    var response = req.options(getenv("REQ_TEST_URL") + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "OPTIONS")


def test_api_head() raises:
    var response = req.head(getenv("REQ_TEST_URL") + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.content(), Bytes())


def test_api_put() raises:
    var response = req.put(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PUT")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_patch() raises:
    var response = req.patch(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PATCH")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_delete() raises:
    var response = req.delete(
        getenv("REQ_TEST_URL") + "/echo",
        content=encode_utf8("Example request body"),
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "DELETE")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_api_invalid_url() raises:
    with assert_raises():
        _ = req.get("invalid://example.com")


def test_api_stream() raises:
    var response = req.stream("GET", getenv("REQ_TEST_URL") + "/chunked")
    assert_equal(response.read(), encode_utf8("hello world"))
    assert_equal(response.read(), encode_utf8("hello world"))
    assert_equal(response.text(), "hello world")


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
