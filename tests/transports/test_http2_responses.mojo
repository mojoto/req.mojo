"""HTTP/2 responses tests."""
from ._http2_helpers import _client
from req import Bytes
from std.testing import assert_equal, assert_true


def test_http2_informational_response_uses_final_headers() raises:
    var client = _client()
    var response = client.get("/informational")
    assert_equal(response.status_code, 200)
    assert_equal(response.text(), "final response")
    assert_equal(response.http_version, "HTTP/2")
    assert_true("Link" not in response.headers)


def test_http2_trailers_are_not_initial_headers() raises:
    var client = _client()
    var response = client.get("/trailers")
    assert_equal(response.text(), "body with trailers")
    assert_true("X-Trailer" not in response.headers)


def test_http2_ping_does_not_interrupt_response() raises:
    var client = _client()
    assert_equal(client.get("/ping").status_code, 200)
    assert_equal(client.get("/bytes").http_version, "HTTP/2")


def test_http2_empty_head_and_no_content_responses_reuse_connection() raises:
    var client = _client()
    var empty = client.post("/echo", content=Bytes())
    assert_equal(empty.json()["size"].int_value(), 0)
    var head = client.head("/bytes")
    var response = client.get("/no-content")
    assert_equal(response.status_code, 204)
    assert_equal(response.content(), Bytes())
    assert_equal(head.content(), Bytes())
    assert_equal(
        response.headers["X-Connection"], empty.headers["X-Connection"]
    )


def test_http2_unknown_extension_frame_is_ignored() raises:
    var client = _client()
    var response = client.get("/extension")
    assert_equal(response.http_version, "HTTP/2")
    assert_equal(response.json()["method"].string_value(), "GET")
