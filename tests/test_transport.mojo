from std.testing import assert_equal, assert_true
from std.os import getenv
from req._transports.default import (
    CurlStream,
    new_pool,
    close_pool,
    release_pool,
)
from req import Timeout
from req._utils import decode_utf8


def test_native_transport() raises:
    var pool = new_pool()
    var response_headers: String
    var content = String()
    var largest = 0
    try:
        var response = CurlStream(
            pool,
            "GET",
            getenv("REQ_TEST_URL") + "/chunked",
            "",
            None,
            Timeout(),
            True,
            None,
        )
        response_headers = response.headers()
        while True:
            var chunk = response.read_chunk(3)
            if not chunk:
                break
            largest = max(largest, len(chunk.value()))
            content += decode_utf8(chunk.value())
        response.close()
    finally:
        close_pool(pool)
        release_pool(pool)
    assert_true("200 OK" in response_headers)
    assert_true(largest <= 3)
    assert_equal(content, "hello world")


comptime TEST_FUNCTIONS = __functions_in_module()
