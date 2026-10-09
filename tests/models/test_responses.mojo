from std.testing import TestSuite, assert_equal, assert_true, assert_raises
from req import Response, Request, Headers, Bytes, encode_utf8


def test_response_status() raises:
    var request = Request("GET", "http://example.com")
    for status in [200, 204, 301, 404, 503]:
        var response = Response(status, request=request)
        assert_equal(response.is_success(), 200 <= status < 300)
        if status >= 400:
            with assert_raises():
                response.raise_for_status()
        else:
            response.raise_for_status()
    var redirect = Response(
        302, request=request, headers=Headers({"Location": "/next"})
    )
    assert_true(redirect.is_redirect())


def test_response_text_and_json() raises:
    var request = Request("GET", "http://example.com")
    var response = Response(
        200, request=request, content=encode_utf8('{"hello":"雪"}')
    )
    assert_equal(response.json()["hello"].string_value(), "雪")
    assert_equal(response.text(), '{"hello":"雪"}')
    var bytes: Bytes = [UInt8(233)]
    var latin = Response(
        200,
        request=request,
        content=bytes,
        headers=Headers({"Content-Type": 'text/plain; charset="iso-8859-1"'}),
    )
    assert_equal(latin.text(), "é")
    with assert_raises():
        _ = latin.text(encoding="ascii")
    with assert_raises():
        _ = latin.text(encoding="utf-8")


def test_empty_response_and_closed_buffer() raises:
    var request = Request("HEAD", "http://example.com")
    var response = Response(
        200, request=request, content=encode_utf8("ignored")
    )
    assert_equal(len(response.content()), 0)
    var empty = Response(204, request=Request("GET", "http://example.com"))
    with assert_raises():
        _ = empty.json()
    var buffered = Response(
        200,
        request=Request("GET", "http://example.com"),
        content=encode_utf8("cached"),
    )
    buffered.close()
    assert_true(buffered.is_closed())
    assert_equal(buffered.text(), "cached")
    assert_equal(len(buffered.read_chunk(9223372036854775807).value()), 6)


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
