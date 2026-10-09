from std.testing import TestSuite, assert_equal, assert_raises
from req import Auth, Headers


def test_basic_auth() raises:
    var headers = Headers()
    Auth.basic("user", "password").apply(headers)
    assert_equal(headers["authorization"], "Basic dXNlcjpwYXNzd29yZA==")
    with assert_raises():
        _ = Auth.basic("bad:user", "password")


def test_bearer_auth_and_explicit_header() raises:
    var headers = Headers()
    Auth.bearer("token").apply(headers)
    assert_equal(headers["authorization"], "Bearer token")
    Auth.basic("other", "password").apply(headers)
    assert_equal(headers["authorization"], "Bearer token")
    for value in ["", "bad token", "bad\nvalue", "雪"]:
        with assert_raises():
            _ = Auth.bearer(value)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
