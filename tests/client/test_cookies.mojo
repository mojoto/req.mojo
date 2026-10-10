"""Cookies tests."""
from req import Client, CookieJar
from std.os import getenv
from std.testing import assert_equal


def test_cookie_copy() raises:
    var original = CookieJar()
    original.set("name", "value", domain="127.0.0.1")
    var client = Client(base_url=getenv("REQ_TEST_URL"), cookies=original)
    original.clear()
    assert_equal(
        client.cookies.get("name", domain="127.0.0.1").value(), "value"
    )
    var response = client.get("/echo")
    assert_equal(
        response.json()["headers"]["Cookie"].string_value(), "name=value"
    )


def test_cookie_persistence() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    _ = client.get("/cookies/set")
    assert_equal(client.cookies.get("a", domain="127.0.0.1").value(), "one")
    var response = client.get("/echo")
    assert_equal(response.json()["headers"]["Cookie"].string_value(), "a=one")
