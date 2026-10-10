"""Auth tests."""
from req import Auth, Client, Headers
from std.os import getenv
from std.testing import assert_equal, assert_raises


def test_basic_client() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), auth=Auth.basic("username", "password")
    )
    var response = client.get("/echo")
    assert_equal(
        response.json()["headers"]["Authorization"].string_value(),
        "Basic dXNlcm5hbWU6cGFzc3dvcmQ=",
    )


def test_basic_stream() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream(
        "GET", "/echo", auth=Auth.basic("username", "password")
    )
    _ = response.read()
    assert_equal(
        response.json()["headers"]["Authorization"].string_value(),
        "Basic dXNlcm5hbWU6cGFzc3dvcmQ=",
    )


def test_auth_disabled() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), auth=Auth.basic("user", "password")
    )
    var response = client.get("/echo", auth=Auth.none())
    with assert_raises():
        _ = response.json()["headers"]["Authorization"]
    var next = client.get("/echo")
    assert_equal(
        next.json()["headers"]["Authorization"].string_value(),
        "Basic dXNlcjpwYXNzd29yZA==",
    )


def test_auth_override() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), auth=Auth.basic("user", "password")
    )
    var request = client.build_request(
        "GET", "/echo", auth=Auth.bearer("override")
    )
    assert_equal(request.headers["Authorization"], "Bearer override")
    request = client.build_request(
        "GET",
        "/echo",
        headers=Headers({"authorization": "explicit"}),
        auth=Auth.bearer("override"),
    )
    assert_equal(request.headers["Authorization"], "explicit")
