from std.testing import TestSuite, assert_equal, assert_true, assert_raises
from std.os import getenv
from req import Client, Headers, Auth, encode_utf8
from req._utils import percent_encode


def test_redirect_methods_and_defaults() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var first = client.get("/redirect")
    assert_equal(first.status_code, 302)
    assert_true(first.is_redirect())
    for code in [301, 302, 303, 307, 308]:
        var response = client.post(
            "/redirect?code=" + String(code),
            content=encode_utf8("payload"),
            headers=Headers({"Content-Type": "text/plain"}),
            follow_redirects=True,
        )
        var result = response.json()
        assert_equal(
            result["method"].string_value(), "POST" if code >= 307 else "GET"
        )
        assert_equal(
            result["body"].string_value(), "payload" if code >= 307 else ""
        )
        assert_equal(response.url.path(), "/echo")
        if code < 307:
            with assert_raises():
                _ = result["headers"]["Content-Type"]
    var response = client.put(
        "/redirect?code=302", content=encode_utf8("keep"), follow_redirects=True
    )
    assert_equal(response.json()["method"].string_value(), "PUT")
    assert_equal(response.json()["body"].string_value(), "keep")


def test_redirect_origin_and_limits() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        auth=Auth.bearer("secret"),
        follow_redirects=True,
        max_redirects=2,
    )
    var target = percent_encode(getenv("REQ_TEST_OTHER_URL") + "/echo")
    var response = client.get(
        "/redirect?to=" + target,
        headers=Headers(
            {"Cookie": "secret=yes", "Proxy-Authorization": "secret"}
        ),
    )
    for key in ["Authorization", "Proxy-Authorization", "Cookie"]:
        with assert_raises():
            _ = response.json()["headers"][key]
    with assert_raises():
        _ = client.get("/loop")
    var none = Client(
        base_url=getenv("REQ_TEST_URL"), follow_redirects=True, max_redirects=0
    )
    with assert_raises():
        _ = none.get("/redirect")


def test_redirect_cookie_selection_and_request_edits() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    client.cookies.set("scoped", "yes", domain="127.0.0.1", path="/redirect")
    var response = client.get("/redirect?to=/echo")
    with assert_raises():
        _ = response.json()["headers"]["Cookie"]
    var request = client.build_request("GET", "/redirect?to=/echo")
    request.headers.set("Cookie", "explicit=edited")
    var edited = client.send(request)
    assert_equal(
        edited.json()["headers"]["Cookie"].string_value(), "explicit=edited"
    )


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
