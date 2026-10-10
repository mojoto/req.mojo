"""Methods tests."""
from req import Bytes, Client, JSONValue, encode_utf8
from std.os import getenv
from std.testing import assert_equal


def test_client_get() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.get("/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "GET")


def test_client_post() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "POST")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_client_options() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.options("/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "OPTIONS")


def test_client_head() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.head("/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.content(), Bytes())


def test_client_put() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.put(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PUT")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_client_patch() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.patch(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "PATCH")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_client_delete() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.delete(
        "/echo", content=encode_utf8("Example request body")
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "DELETE")
    assert_equal(response.json()["body"].string_value(), "Example request body")


def test_post_json() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/echo", json=JSONValue.parse('{"hello":"world"}')
    )
    assert_equal(response.json()["body"].string_value(), '{"hello":"world"}')
    assert_equal(
        response.json()["headers"]["Content-Type"].string_value(),
        "application/json",
    )
