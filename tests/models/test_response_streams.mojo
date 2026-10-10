"""Response streams tests."""
from req import Request, Response, Timeout
from req._transports.default import CurlStream, new_pool, release_pool
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def _response(path: String) raises -> Response:
    var pool = new_pool()
    var source: CurlStream
    try:
        source = CurlStream(
            pool,
            "GET",
            getenv("REQ_TEST_URL") + path,
            "",
            None,
            Timeout(),
            True,
            None,
        )
    except error:
        release_pool(pool)
        raise error
    source.owns_pool = pool
    return Response.from_stream(
        source^, Request("GET", getenv("REQ_TEST_URL") + path)
    )


def test_stream_response_state() raises:
    var response = _response("/bytes")
    with assert_raises():
        _ = response.text()
    _ = response.read_chunk(1)
    with assert_raises():
        _ = response.read()
    response.close()
    assert_true(response.is_closed())
    with assert_raises():
        _ = response.read_chunk()


def test_stream_response_cache() raises:
    var response = _response("/chunked")
    _ = response.read()
    assert_equal(response.text(), "hello world")
    response.close()
    assert_equal(len(response.content()), 11)
