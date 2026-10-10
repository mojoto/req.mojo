"""Auth tests."""
from req import Auth, Headers
from std.testing import assert_equal, assert_raises


def test_basic_normal() raises:
    var headers = Headers()
    Auth.basic("username", "password").apply(headers)
    assert_equal(headers["Authorization"], "Basic dXNlcm5hbWU6cGFzc3dvcmQ=")


def test_basic_empty() raises:
    var headers = Headers()
    Auth.basic("", "").apply(headers)
    assert_equal(headers["Authorization"], "Basic Og==")


def test_basic_colon_password() raises:
    var headers = Headers()
    Auth.basic("user", "a:b").apply(headers)
    assert_equal(headers["Authorization"], "Basic dXNlcjphOmI=")


def test_basic_unicode() raises:
    var headers = Headers()
    Auth.basic("é", "雪").apply(headers)
    assert_equal(headers["Authorization"], "Basic w6k66Zuq")


def test_auth_invalid() raises:
    with assert_raises():
        _ = Auth.basic("user:name", "password")
    for value in ["", "space token", "a\n", "a\r", "a\t", "雪"]:
        with assert_raises():
            _ = Auth.bearer(value)


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
