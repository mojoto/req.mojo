"""HTTPX 0.28.1 parameterized scenarios adapted to native Mojo assertions."""
from std.testing import assert_equal, assert_true
from std.os import getenv
from req import (
    URL,
    Client,
    Headers,
    QueryParams,
    Request,
    Response,
    Bytes,
    ErrorKind,
    encode_utf8,
)


def rejected_url(text: String) raises:
    var caught = False
    try:
        _ = URL(text)
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught, text)


def invalid_client_url(text: String) raises:
    var client = Client()
    var caught = False
    try:
        _ = client.get(text)
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught, text)


def url_components(text: String, path: String, query: String) raises:
    var url = URL(text)
    assert_equal(url.path(), path)
    assert_equal(url.query(), query)
    assert_equal(
        String(url),
        "https://example.com"
        + path
        + ("?" + query if "?" in text.split("#")[0] else ""),
    )


def queryparams(source: String) raises:
    var params = QueryParams(source)
    if source == "pairs":
        params = QueryParams(
            List[Tuple[String, String]](
                [("a", "123"), ("a", "456"), ("b", "789")]
            )
        )
    assert_true("a" in params and "A" not in params and "c" not in params)
    assert_equal(params["a"], "123")
    assert_equal(params.get("a").value(), "123")
    assert_true(not params.get("missing"))
    assert_equal(params.get_all("a"), List[String](["123", "456"]))
    assert_equal(len(params), 3)
    assert_equal(String(params), "a=123&a=456&b=789")
    var pairs = params.items()
    assert_equal(
        pairs,
        List[Tuple[String, String]]([("a", "123"), ("a", "456"), ("b", "789")]),
    )
    pairs[0] = ("a", "changed")
    assert_equal(params["a"], "123")


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


def decoder_empty(encoding: String, buffered: Bool) raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var url = "/encoded?kind=" + encoding + "&zero=1"
    if buffered:
        assert_equal(client.get(url).content(), Bytes())
    else:
        var response = client.stream("GET", url)
        assert_equal(response.read(), Bytes())
        assert_true(response.is_closed())


def decoder_error(encoding: String) raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var url = "/encoded?kind=" + encoding + "&invalid=1"
    var response = client.stream("GET", url)
    var caught = False
    try:
        _ = response.read()
    except error:
        assert_equal(error.kind, ErrorKind.DecodeError)
        assert_equal(error.method.value(), "GET")
        assert_equal(error.url.value(), getenv("REQ_TEST_URL") + url)
        caught = True
    assert_true(caught, encoding)
    assert_true(response.is_closed())


def fragmented_gzip() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/encoded?kind=gzip&fragment=1")
    var body = Bytes()
    while True:
        var chunk = response.read_chunk(1)
        if not chunk:
            break
        for byte in chunk.value():
            body.append(byte)
    assert_equal(body, encode_utf8("test 123"))
    assert_true(response.is_closed())


def multipart_boundary(header: String) raises:
    from .test_uploads import check_explicit_boundary

    check_explicit_boundary(header)


def test_decoder_empty_parameters() raises:
    decoder_empty("deflate", False)
    decoder_empty("deflate", True)
    decoder_empty("gzip", False)
    decoder_empty("gzip", True)
    decoder_empty("identity", False)
    decoder_empty("identity", True)


def test_decoder_error_parameters() raises:
    decoder_error("deflate")
    decoder_error("gzip")


def test_fragmented_gzip_parameters() raises:
    fragmented_gzip()


def test_invalid_client_url_parameters() raises:
    invalid_client_url("://example.com")
    invalid_client_url("http://")
    invalid_client_url("invalid://example.com")


def test_json_encoding_parameters() raises:
    json_encoding(False, "")
    json_encoding(False, "application/json")
    json_encoding(False, "application/json; charset=utf-8")
    json_encoding(True, "")
    json_encoding(True, "application/json")
    json_encoding(True, "application/json; charset=utf-8-sig")


def test_multipart_boundary_parameters() raises:
    multipart_boundary('multipart/form-data; boundary="+++"')
    multipart_boundary('multipart/form-data; boundary="+++" ;')
    multipart_boundary('multipart/form-data; boundary="+++"; charset=utf-8')
    multipart_boundary("multipart/form-data; boundary=+++")
    multipart_boundary("multipart/form-data; boundary=+++ ;")
    multipart_boundary("multipart/form-data; boundary=+++; charset=utf-8")
    multipart_boundary('multipart/form-data; charset=utf-8; boundary="+++"')
    multipart_boundary("multipart/form-data; charset=utf-8; boundary=+++")


def test_queryparams_parameters() raises:
    queryparams("a=123&a=456&b=789")
    queryparams("pairs")


def test_rejected_url_parameters() raises:
    rejected_url("http://!\"$&'()*+,-.;=_`{}~/")
    rejected_url("http://%25DOMAIN:foobar@foodomain.com/")
    rejected_url("http://%60%7B%7D:%60%7B%7D@h/%60%7B%7D?`{}")
    rejected_url("http://&a:foo(b%5Dc@d:2/")
    rejected_url("http://:%3A%40c@d:2/")
    rejected_url("http://:b@www.example.com/")
    rejected_url("http://a:b@c/")
    rejected_url("http://a:b@c:29/d")
    rejected_url("http://a:b@www.example.com/")
    rejected_url("http://a@www.example.com/")
    rejected_url("http://example.com/foo%")
    rejected_url("http://example.com/foo%2")
    rejected_url("http://example.com/foo%2%C3%82%C2%A9zbar")
    rejected_url("http://example.com/foo%2zbar")
    rejected_url("http://example.com/foo/%2e%2")
    rejected_url("http://example.com/test?%GH")
    rejected_url("http://f:0/c")
    rejected_url("http://foo.com:b@d/")
    rejected_url("http://foo:%F0%9F%92%A9@example.com/bar")
    rejected_url("http://user:pass@example.com:21/smth")
    rejected_url("http://user:pass@example.com:21/some/path")
    rejected_url("http://user:pass@foo:21/bar;par?b#c")
    rejected_url("http://user@example.com/some/path")
    rejected_url("http://www.@pple.com/")
    rejected_url("https://%40%40@example/")
    rejected_url("https://%40test%40test@example:800/")
    rejected_url("https://test@test/")
    rejected_url("https://user name:p@ssword@example.com")
    rejected_url("https://user%20name:p%40ssword@example.com")
    rejected_url("https://user:pass%5B%7F@foo/bar")
    rejected_url("https://username%40gmail.com:pa%20ssword@example.com")
    rejected_url("https://username:password@example.com")
    rejected_url("https://username@gmail.com:pa ssword@example.com")


def test_url_components_parameters() raises:
    url_components("https://example.com/ %61%62%63", "/%20%61%62%63", "")
    url_components(
        "https://example.com/!$&'()*+,;= abc ABC 123 :/[]@",
        "/!$&'()*+,;=%20abc%20ABC%20123%20:/[]@",
        "",
    )
    url_components(
        "https://example.com/!$&'()*+,;=%20abc%20ABC%20123%20:/[]@",
        "/!$&'()*+,;=%20abc%20ABC%20123%20:/[]@",
        "",
    )
    url_components(
        "https://example.com/#!$&'()*+,;= abc ABC 123 :/[]@?#", "/", ""
    )
    url_components(
        "https://example.com/?!$&%27()*+,;=%20abc%20ABC%20123%20:%2F[]@?",
        "/",
        "!$&%27()*+,;=%20abc%20ABC%20123%20:%2F[]@?",
    )
    url_components(
        "https://example.com/?!$&'()*+,;= abc ABC 123 :/[]@?",
        "/",
        "!$&'()*+,;=%20abc%20ABC%20123%20:/[]@?",
    )
    url_components("https://example.com/?%20%97%98%99", "/", "%20%97%98%99")
