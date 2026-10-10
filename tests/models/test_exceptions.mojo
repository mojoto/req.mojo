"""Exceptions tests."""
from req import ErrorKind, HTTPError
from std.testing import assert_equal, assert_true


def raise_timeout() raises HTTPError:
    raise HTTPError(
        ErrorKind.ReadTimeout,
        "Read timed out",
        method="GET",
        url="https://example.com/",
    )


def test_typed_error() raises:
    try:
        raise_timeout()
    except error:
        assert_equal(error.kind, ErrorKind.ReadTimeout)
        assert_equal(error.method.value(), "GET")
        assert_equal(error.url.value(), "https://example.com/")
        assert_true(not error.status_code)


def test_status_context() raises:
    var error = HTTPError(
        ErrorKind.HTTPStatusError, "HTTP status error", status_code=404
    )
    assert_equal(error.status_code.value(), 404)
    assert_equal(String(error), "HTTPStatusError: HTTP status error")
