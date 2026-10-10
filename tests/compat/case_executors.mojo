"""Assertions for individually collected parameter cases."""
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


def canonical_url(
    href: String,
    scheme: String,
    host: String,
    port: Int,
    path: String,
    query: String,
) raises:
    var url = URL(href)
    assert_equal(url.scheme(), scheme)
    assert_equal(url.host(), host)
    assert_equal(url.port(), port)
    assert_equal(url.path(), path)
    assert_equal(url.query(), query)
    assert_true("#" not in String(url))


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
