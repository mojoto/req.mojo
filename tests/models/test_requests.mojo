"""Requests tests."""
from req import Bytes, Headers, JSONValue, QueryParams, Request, encode_utf8
from req._content import encode_body
from std.testing import assert_equal, assert_raises, assert_true


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


def test_request_body_presence_and_copy() raises:
    var empty = Bytes()
    var absent = Request("get", "http://example.com")
    var present = Request("POST", "http://example.com", content=empty.copy())
    assert_equal(absent.method, "GET")
    assert_true(not absent.content)
    assert_true(Bool(present.content))
    assert_equal(len(present.content.value()), 0)
    var body = encode_utf8("original")
    var request = Request("POST", "http://example.com", content=body.copy())
    body[0] = 120
    assert_equal(request.content.value()[0], UInt8(111))
    assert_equal(Request("custom", "http://example.com").method, "custom")


def test_request_validation() raises:
    var body = encode_utf8("abc")
    for header in ["2", "4", "-3", "3, 3"]:
        with assert_raises():
            _ = Request(
                "POST",
                "http://example.com",
                headers=Headers({"Content-Length": header}),
                content=body.copy(),
            )
    with assert_raises():
        _ = Request("HEAD", "http://example.com", content=body.copy())
    with assert_raises():
        _ = Request("GET\n", "http://example.com")
    with assert_raises():
        _ = Request(
            "POST",
            "http://example.com",
            headers=Headers({"Transfer-Encoding": "chunked"}),
        )


def test_body_encoders() raises:
    var headers = Headers()
    var form = encode_body(headers, data=QueryParams({"a": "b c"}))
    assert_equal(headers["content-type"], "application/x-www-form-urlencoded")
    assert_equal(form.value(), encode_utf8("a=b+c"))
    var json_headers = Headers()
    var json = encode_body(json_headers, json=JSONValue.null())
    assert_equal(json.value(), encode_utf8("null"))
    assert_equal(json_headers["content-type"], "application/json")
    with assert_raises():
        _ = encode_body(headers, data=QueryParams(), json=JSONValue.null())
