"""Exercise installed modules and native loading from outside the checkout."""

import req
from std.os import getenv
from std.testing import assert_equal, assert_true


def surviving_response(url: String) raises -> req.Response:
    var client = req.Client()
    return client.stream("GET", url)


def main() raises:
    if getenv("REQ_EXPECT_LOAD_ERROR"):
        try:
            var client = req.Client()
        except error:
            assert_equal(error.kind, req.ErrorKind.ConnectError)
            assert_true(
                "Req" in error.message or "REQ_NATIVE_LIB" in error.message
            )
            return
        raise Error("Expected a native library loading error")

    var url = getenv("REQ_TEST_URL")
    var response = req.get(url + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "GET")

    var client = req.Client()
    var payload = req.JSONValue.object()
    payload.set("name", req.JSONValue("Mojo"))
    var posted = client.post(url + "/echo", json=payload)
    assert_equal(posted.json()["body"].string_value(), '{"name":"Mojo"}')
    client.close()

    # The response retains its pool even after the local Client is destroyed.
    var streamed = surviving_response(url + "/chunked")
    _ = streamed.read()
    assert_equal(streamed.text(), "hello world")
    print("Req package HTTP, JSON, and streaming tests passed")
