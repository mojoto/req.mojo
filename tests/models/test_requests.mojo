from std.testing import assert_equal, assert_true, assert_raises
from req import Request, Headers, Bytes, encode_utf8, QueryParams, JSONValue
from req._content import encode_body


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


comptime TEST_FUNCTIONS = __functions_in_module()
