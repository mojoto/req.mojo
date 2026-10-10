"""Pinned v0.28.1 scenarios adapted to the native synchronous API."""
from std.testing import assert_equal, assert_true, assert_raises
from req import (
    Headers,
    QueryParams,
    Request,
    Response,
    Bytes,
    JSONValue,
    encode_utf8,
    ErrorKind,
)
from req._content import encode_body


def test_headers() raises:
    var h = Headers(
        List[Tuple[String, String]]([("a", "123"), ("A", "456"), ("b", "789")])
    )
    assert_true("a" in h and "A" in h and "b" in h and "B" in h)
    assert_true("c" not in h)
    assert_equal(h["a"], "123")
    assert_true(not h.get("missing"))
    assert_equal(h.get_all("A"), List[String](["123", "456"]))
    assert_equal(len(h), 3)
    assert_equal(
        h.items(),
        List[Tuple[String, String]]([("a", "123"), ("A", "456"), ("b", "789")]),
    )


def test_header_mutations() raises:
    var h = Headers()
    assert_equal(len(h), 0)
    h.set("a", "1")
    h.set("A", "2")
    assert_equal(h["a"], "2")
    h.set("b", "4")
    h.remove("a")
    assert_equal(h.items(), List[Tuple[String, String]]([("b", "4")]))
    h.remove("missing")
    assert_equal(len(h), 1)


def test_headers_copy() raises:
    var h = Headers({"custom": "example"})
    var copied = h
    copied.set("custom", "changed")
    assert_equal(h["custom"], "example")
    assert_equal(copied["custom"], "changed")


def test_headers_items_snapshot() raises:
    var h = Headers({"custom": "example"})
    var items = h.items()
    items[0] = ("custom", "changed")
    assert_equal(h["custom"], "example")


def test_headers_retain_order() raises:
    var h = Headers(
        List[Tuple[String, String]]([("a", "a"), ("b", "b"), ("c", "c")])
    )
    h.set("B", "123")
    assert_equal(
        h.items(),
        List[Tuple[String, String]]([("a", "a"), ("B", "123"), ("c", "c")]),
    )


def test_headers_append_new() raises:
    var h = Headers(
        List[Tuple[String, String]]([("a", "a"), ("b", "b"), ("c", "c")])
    )
    h.set("d", "123")
    assert_equal(h.items()[3], (String("d"), String("123")))


def test_headers_replace_all() raises:
    var h = Headers(List[Tuple[String, String]]([("a", "123"), ("A", "456")]))
    h.set("a", "789")
    assert_equal(len(h), 1)
    assert_equal(h["a"], "789")


def test_headers_remove_all() raises:
    var h = Headers(List[Tuple[String, String]]([("a", "123"), ("A", "456")]))
    h.remove("A")
    assert_equal(len(h), 0)


def test_headers_multiple() raises:
    var h = Headers(
        List[Tuple[String, String]](
            [("Set-Cookie", "a, b"), ("set-cookie", "c")]
        )
    )
    assert_equal(h.get_all("SET-COOKIE"), List[String](["a, b", "c"]))


def test_headers_merge_multivalue() raises:
    var h = Headers(
        List[Tuple[String, String]](
            [("keep", "yes"), ("a", "old"), ("A", "old2")]
        )
    )
    h.merge(Headers(List[Tuple[String, String]]([("a", "one"), ("A", "two")])))
    assert_equal(h.get_all("a"), List[String](["one", "two"]))
    assert_equal(h["keep"], "yes")


def test_queryparams() raises:
    var p = QueryParams("a=123&a=456&b=789")
    assert_true("a" in p and "A" not in p and "c" not in p)
    assert_equal(p["a"], "123")
    assert_true(not p.get("missing"))
    assert_equal(p.get_all("a"), List[String](["123", "456"]))
    assert_equal(len(p), 3)
    assert_equal(String(p), "a=123&a=456&b=789")
    var pairs = p.items()
    pairs[0] = ("a", "changed")
    assert_equal(p["a"], "123")


def test_params_set() raises:
    var p = QueryParams("a=123&a=456&b=789")
    p.set("a", "000")
    assert_equal(String(p), "a=000&b=789")


def test_params_add() raises:
    var p = QueryParams("a=123")
    p.add("a", "456")
    assert_equal(String(p), "a=123&a=456")


def test_params_remove() raises:
    var p = QueryParams("a=123&a=456&b=789")
    p.remove("a")
    p.remove("missing")
    assert_equal(String(p), "b=789")


def test_params_merge() raises:
    var p = QueryParams("a=123")
    p.merge(QueryParams("b=456"))
    assert_equal(String(p), "a=123&b=456")
    p.merge(QueryParams("a=000&c=789"))
    assert_equal(p["a"], "000")
    assert_equal(p["b"], "456")
    assert_equal(p["c"], "789")


def test_params_copy() raises:
    var p = QueryParams("a=123")
    var copied = p
    copied.set("a", "changed")
    assert_equal(p["a"], "123")


def test_params_empty_separators() raises:
    var p = QueryParams("a=1&&b=2&")
    assert_equal(
        p.items(), List[Tuple[String, String]]([("a", "1"), ("b", "2")])
    )
    assert_equal(len(QueryParams("&&")), 0)
    assert_equal(QueryParams("=empty")[""], "empty")


def test_request_no_content() raises:
    var request = Request("GET", "http://example.com")
    assert_true(not request.content)
    assert_true("Content-Length" not in request.headers)


def test_request_length() raises:
    var request = Request(
        "POST",
        "http://example.com",
        content=encode_utf8("test 123"),
        headers=Headers({"Content-Length": "8"}),
    )
    request.validate()
    assert_equal(request.headers["Content-Length"], "8")
    assert_equal(request.content.value(), encode_utf8("test 123"))


def test_request_override_host() raises:
    var request = Request(
        "GET", "http://example.com", headers=Headers({"host": "1.2.3.4:80"})
    )
    assert_equal(request.headers["host"], "1.2.3.4:80")


def test_request_override_accept_encoding() raises:
    var request = Request(
        "GET",
        "http://example.com",
        headers=Headers({"Accept-Encoding": "identity"}),
    )
    assert_equal(request.headers["Accept-Encoding"], "identity")


def test_request_url() raises:
    var request = Request("GET", "https://example.com/abc?foo=bar")
    assert_equal(request.url.scheme(), "https")
    assert_equal(request.url.port(), 443)
    assert_equal(request.url.path(), "/abc")
    assert_equal(request.url.query(), "foo=bar")


def test_request_copy() raises:
    var request = Request(
        "POST",
        "http://example.com",
        content=encode_utf8("original"),
        headers=Headers({"X": "original"}),
    )
    var copied = request
    copied.headers.set("X", "changed")
    copied.content.value()[0] = 120
    assert_equal(request.headers["X"], "original")
    assert_equal(request.content.value(), encode_utf8("original"))


def test_form_encoded() raises:
    var headers = Headers()
    var body = encode_body(
        headers, data=QueryParams("test=123&test=456&space=a+b&unicode=%C3%A7")
    )
    assert_equal(headers["Content-Type"], "application/x-www-form-urlencoded")
    assert_equal(
        body.value(), encode_utf8("test=123&test=456&space=a+b&unicode=%C3%A7")
    )


def test_json_encoded() raises:
    var headers = Headers()
    var body = encode_body(headers, json=JSONValue.parse('{"test":123}'))
    assert_equal(headers["Content-Type"], "application/json")
    assert_equal(body.value(), encode_utf8('{"test":123}'))


def test_json_unicode() raises:
    var headers = Headers()
    var body = encode_body(
        headers, json=JSONValue.parse('{"greeting":"Bonjour, ça va ?"}')
    )
    assert_equal(body.value(), encode_utf8('{"greeting":"Bonjour, ça va ?"}'))


def test_json_compact() raises:
    var headers = Headers()
    var body = encode_body(
        headers, json=JSONValue.parse('{ "clé": "valeur", "liste": [1, 2, 3] }')
    )
    assert_equal(body.value(), encode_utf8('{"clé":"valeur","liste":[1,2,3]}'))


def test_body_presence() raises:
    var headers = Headers()
    assert_true(not encode_body(headers))
    var content = encode_body(headers, content=Bytes())
    assert_true(Bool(content))
    assert_equal(len(content.value()), 0)
    var bytes = encode_body(headers, content=encode_utf8("test 123"))
    assert_equal(bytes.value(), encode_utf8("test 123"))


def test_encoder_explicit_type() raises:
    var headers = Headers({"Content-Type": "custom/type"})
    _ = encode_body(headers, data=QueryParams("a=1"))
    assert_equal(headers["Content-Type"], "custom/type")
    _ = encode_body(headers, json=JSONValue.null())
    assert_equal(headers["Content-Type"], "custom/type")


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


def test_empty_query_params() raises:
    for query in ["a=", "a"]:
        assert_equal(String(QueryParams(query)), "a=")
    assert_equal(String(QueryParams("")), "")


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


comptime TEST_FUNCTIONS = __functions_in_module()
