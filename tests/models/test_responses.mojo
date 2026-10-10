"""Responses tests."""
from req import Bytes, ErrorKind, Headers, Request, Response, encode_utf8
from std.testing import assert_equal, assert_raises, assert_true


def _buffered(content: Bytes, headers: Headers = Headers()) raises -> Response:
    return Response(
        200,
        request=Request("GET", "https://example.com/"),
        content=content,
        headers=headers,
    )


def test_response() raises:
    var request = Request("GET", "https://example.com/")
    var response = Response(
        200,
        request=request,
        content=encode_utf8("Hello, world!"),
        reason_phrase="OK",
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.reason_phrase, "OK")
    assert_equal(response.http_version, "HTTP/1.1")
    assert_equal(response.text(), "Hello, world!")
    assert_equal(response.request.method, "GET")
    assert_equal(response.url, request.url)
    assert_true(response.is_success())


def test_response_empty() raises:
    var response = _buffered(Bytes())
    assert_equal(response.content(), Bytes())
    assert_equal(response.read(), Bytes())
    assert_equal(response.text(), "")
    assert_true(not response.read_chunk())


def test_response_content_copy() raises:
    var body = encode_utf8("Hello, world!")
    var response = _buffered(body.copy())
    body[0] = 120
    var snapshot = response.content()
    snapshot[0] = 120
    assert_equal(response.content(), encode_utf8("Hello, world!"))


def test_response_json() raises:
    var response = _buffered(encode_utf8('{"hello":"world"}'))
    assert_equal(response.json()["hello"].string_value(), "world")


def test_response_explicit_encoding() raises:
    var bytes: Bytes = [UInt8(255)]
    var response = _buffered(
        bytes, Headers({"Content-Type": "text/plain; charset=utf-8"})
    )
    assert_equal(response.text(encoding="latin-1"), "ÿ")
    with assert_raises():
        _ = response.text()


def test_response_unknown_encoding() raises:
    var response = _buffered(
        encode_utf8("Hello"),
        Headers({"Content-Type": "text/plain; charset=not-a-charset"}),
    )
    var caught = False
    try:
        _ = response.text()
    except error:
        assert_equal(error.kind, ErrorKind.DecodeError)
        caught = True
    assert_true(caught)


def test_status_unknown() raises:
    var response = Response(299, request=Request("GET", "https://example.com/"))
    assert_equal(response.status_code, 299)
    assert_true(response.is_success())
    assert_true(not response.is_redirect())


def test_redirect_requires_location() raises:
    var response = Response(302, request=Request("GET", "https://example.com/"))
    assert_true(not response.is_redirect())


def test_response_text_html() raises:
    var plain = _buffered(
        encode_utf8("Hello, world!"),
        Headers({"Content-Type": "text/plain; charset=utf-8"}),
    )
    assert_equal(plain.text(), "Hello, world!")
    var html = _buffered(
        encode_utf8("<html><body>Hello, world!</body></html>"),
        Headers({"Content-Type": "text/html; charset=utf-8"}),
    )
    assert_equal(html.text(), "<html><body>Hello, world!</body></html>")


def test_response_read_cached() raises:
    var response = _buffered(encode_utf8("Hello, world!"))
    assert_equal(response.read(), encode_utf8("Hello, world!"))
    assert_equal(response.read(), encode_utf8("Hello, world!"))
    response.close()
    assert_equal(response.text(), "Hello, world!")


def test_response_latin1_requires_charset() raises:
    var bytes: Bytes = [UInt8(255)]
    var response = _buffered(bytes)
    var caught = False
    try:
        _ = response.text()
    except error:
        assert_equal(error.kind, ErrorKind.DecodeError)
        caught = True
    assert_true(caught)


def test_response_force_per_call() raises:
    var bytes: Bytes = [UInt8(195), UInt8(169)]
    var response = _buffered(bytes)
    assert_equal(response.text(), "é")
    assert_equal(response.text(encoding="latin-1"), "Ã©")
    assert_equal(response.text(), "é")


def test_raise_for_status() raises:
    for code in [
        100,
        101,
        199,
        200,
        204,
        299,
        300,
        301,
        302,
        303,
        304,
        307,
        308,
        399,
        400,
        404,
        499,
        500,
        503,
        599,
    ]:
        var response = Response(
            code,
            request=Request("PATCH", "https://example.com/"),
            headers=Headers({"Location": "/next"}),
        )
        assert_equal(response.is_success(), 200 <= code < 300)
        assert_equal(response.is_redirect(), code in [301, 302, 303, 307, 308])
        var caught = False
        try:
            response.raise_for_status()
        except error:
            assert_equal(error.kind, ErrorKind.HTTPStatusError)
            assert_equal(error.status_code.value(), code)
            assert_equal(error.method.value(), "PATCH")
            assert_equal(error.url.value(), "https://example.com/")
            caught = True
        assert_equal(caught, code >= 400)


def test_iter_bytes_with_chunk_size() raises:
    for size in [1, 2, 3, 13, 64, 9223372036854775807]:
        var response = _buffered(encode_utf8("Hello, world!"))
        var content = Bytes()
        while True:
            var chunk = response.read_chunk(size)
            if not chunk:
                break
            assert_true(0 < len(chunk.value()) <= size)
            for byte in chunk.value():
                content.append(byte)
        assert_equal(content, encode_utf8("Hello, world!"))
        assert_true(not response.read_chunk())
        assert_equal(response.read(), encode_utf8("Hello, world!"))


def test_response_default_to_utf8_encoding() raises:
    var response = _buffered(encode_utf8("Hello, world!"))
    assert_equal(response.text(), "Hello, world!")
    for charset in ["ascii", "us-ascii", "utf-8", "utf8"]:
        var text = String("雪é") if charset.startswith("utf") else String(
            "Hello, world!"
        )
        var content = _buffered(
            encode_utf8(text),
            Headers({"Content-Type": "text/plain; charset=" + charset}),
        )
        assert_equal(content.text(), text)


def test_response_content_type_encoding() raises:
    for charset in ["latin-1", "latin1", "iso-8859-1", '"ISO-8859-1"']:
        var bytes: Bytes = [UInt8(76), UInt8(255)]
        var response = _buffered(
            bytes, Headers({"Content-Type": "text/plain; CHARSET = " + charset})
        )
        assert_equal(response.text(), "Lÿ")


def test_json_requires_valid_utf8_content() raises:
    var bytes: Bytes = [UInt8(0), UInt8(0), UInt8(0), UInt8(0)]
    var response = _buffered(bytes)
    var caught = False
    try:
        _ = response.json()
    except error:
        assert_equal(error.kind, ErrorKind.JSONDecodeError)
        caught = True
    assert_true(caught)


def test_json_utf8_bom() raises:
    var body: Bytes = [UInt8(239), UInt8(187), UInt8(191)]
    for byte in encode_utf8('{"abc":123}'):
        body.append(byte)
    for content_type in ["application/json", "application/json; charset=utf-8"]:
        var response = _buffered(
            body.copy(), Headers({"Content-Type": content_type})
        )
        assert_equal(response.json()["abc"].int_value(), 123)


def test_json_without_specified_charset() raises:
    for content_type in ["application/json", "application/json; charset=utf-8"]:
        var response = _buffered(
            encode_utf8('{"abc":123}'), Headers({"Content-Type": content_type})
        )
        assert_equal(response.json()["abc"].int_value(), 123)


def test_text_decoder_empty_cases() raises:
    for charset in ["utf-8", "ascii", "latin-1"]:
        var response = _buffered(
            Bytes(), Headers({"Content-Type": "text/plain; charset=" + charset})
        )
        assert_equal(response.text(), "")


def json_encoding(with_bom: Bool, content_type: String) raises:
    var body = Bytes()
    if with_bom:
        body = [UInt8(239), UInt8(187), UInt8(191)]
    for byte in encode_utf8('{"abc": 123}'):
        body.append(byte)
    var headers = Headers()
    if content_type:
        headers.set("Content-Type", content_type)
    var response = Response(
        200,
        headers=headers,
        request=Request("GET", "http://example.com/"),
        content=body^,
    )
    assert_equal(response.json()["abc"].int_value(), 123)


def test_json_encoding_parameters() raises:
    json_encoding(False, "")
    json_encoding(False, "application/json")
    json_encoding(False, "application/json; charset=utf-8")
    json_encoding(True, "")
    json_encoding(True, "application/json")
    json_encoding(True, "application/json; charset=utf-8-sig")


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
