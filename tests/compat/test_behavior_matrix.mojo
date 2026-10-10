"""Parameter combinations at URL, redirect and decoded stream boundaries."""
from std.testing import assert_equal, assert_true
from std.os import getenv
from req import URL, Client, Headers, QueryParams, Bytes, ErrorKind, encode_utf8


def test_url_control_characters() raises:
    var base = URL("http://example.com/")
    for byte in range(33):
        for component in ["/path", "/?query", "/#fragment"]:
            var text = component + String(chr(127 if byte == 32 else byte))
            for direct in [True, False]:
                var caught = False
                try:
                    if direct:
                        _ = URL("http://example.com" + text)
                    else:
                        _ = base.resolve(text)
                except error:
                    assert_equal(error.kind, ErrorKind.InvalidURL)
                    caught = True
                assert_true(
                    caught, "Control character accepted in " + component
                )


def test_origin_equivalence() raises:
    for pair in [
        ("http://example.com", "HTTP://EXAMPLE.COM:80/"),
        ("https://example.com", "HTTPS://EXAMPLE.COM:443/"),
        ("http://example.com:123", "http://example.com:0123/path?q=1"),
    ]:
        assert_equal(URL(pair[0]).origin(), URL(pair[1]).origin())
    for pair in [
        ("http://example.com", "https://example.com"),
        ("https://example.com", "https://www.example.com"),
        ("https://example.com", "https://example.com:1337"),
        ("http://example.com:9999", "https://example.com:1337"),
    ]:
        assert_true(URL(pair[0]).origin() != URL(pair[1]).origin())


def test_client_invalid_url_variants() raises:
    var client = Client()
    for url in ["invalid://example.com", "://example.com", "http://"]:
        var caught = False
        try:
            _ = client.get(url)
        except error:
            assert_equal(error.kind, ErrorKind.InvalidURL)
            caught = True
        assert_true(caught, url)


def test_queryparams_pair_constructor() raises:
    var params = QueryParams(
        List[Tuple[String, String]](
            [
                ("a", "123"),
                ("a", "456"),
                ("b", "789"),
            ]
        )
    )
    assert_equal(params.get_all("a"), List[String](["123", "456"]))
    assert_equal(params["b"], "789")
    assert_equal(String(params), "a=123&a=456&b=789")
    assert_equal(QueryParams({"a": "123"})["a"], "123")


def test_redirect_method_and_body_matrix() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for method in ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"]:
        for code in [301, 302, 303, 307, 308]:
            for with_body in [False, True]:
                if method == "HEAD" and with_body:
                    continue
                var body: Optional[Bytes] = None
                var headers = Headers()
                if with_body:
                    body = encode_utf8("test 123")
                    headers.set("Content-Type", "text/plain")
                var response = client.stream(
                    method,
                    "/redirect?code=" + String(code),
                    content=body,
                    headers=headers,
                    follow_redirects=True,
                )
                var drops_body = (code == 303 and method != "HEAD") or (
                    code in [301, 302] and method == "POST"
                )
                assert_equal(response.status_code, 200)
                assert_equal(
                    response.request.method, "GET" if drops_body else method
                )
                assert_equal(response.url.path(), "/echo")
                _ = response.read()
                if method == "HEAD":
                    assert_equal(response.content(), Bytes())
                else:
                    assert_equal(
                        response.json()["method"].string_value(),
                        "GET" if drops_body else method,
                    )
                    assert_equal(
                        response.json()["body"].string_value(),
                        "test 123" if with_body and not drops_body else "",
                    )
                if drops_body:
                    assert_true(not response.request.content)
                    assert_true("Content-Type" not in response.request.headers)
                elif with_body:
                    assert_equal(
                        response.request.content.value(),
                        encode_utf8("test 123"),
                    )


def test_redirect_hostname_updates_host_and_credentials() raises:
    var source = getenv("REQ_TEST_URL")
    var target = source.replace("127.0.0.1", "localhost") + "/echo"
    var client = Client(base_url=source, follow_redirects=True)
    var headers = Headers(
        {
            "Host": "example.com",
            "Authorization": "secret",
            "Proxy-Authorization": "secret",
            "Cookie": "explicit=secret",
        }
    )
    var response = client.get(
        "/redirect?to="
        + String(QueryParams({"to": target})).removeprefix("to="),
        headers=headers,
    )
    assert_equal(String(response.url), target)
    assert_equal(
        response.json()["headers"]["Host"].string_value(),
        "localhost:" + String(URL(source).port()),
    )
    for name in ["Authorization", "Proxy-Authorization", "Cookie"]:
        assert_true(name not in response.request.headers)


def test_decoder_fragmented_body_and_chunk_size_matrix() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for encoding in [
        "identity",
        "gzip",
        "deflate",
        "raw-deflate",
        "multi",
        "multi-raw",
    ]:
        for payload in ["empty", "text", "binary"]:
            var expected = Bytes()
            var url = "/encoded?kind=" + encoding + "&fragment=1"
            if payload == "empty":
                url += "&empty=1"
            elif payload == "binary":
                url += "&payload=binary"
                for _ in range(8):
                    for byte in range(256):
                        expected.append(UInt8(byte))
            else:
                expected = encode_utf8("test 123")
            for size in [1, 5, 7, 13, 20, 65536]:
                var response = client.stream("GET", url)
                var received = Bytes()
                while True:
                    var chunk: Optional[Bytes]
                    try:
                        chunk = response.read_chunk(size)
                    except error:
                        raise Error(
                            encoding
                            + "/"
                            + payload
                            + "/"
                            + String(size)
                            + ": "
                            + String(error)
                        )
                    if not chunk:
                        break
                    assert_true(0 < len(chunk.value()) <= size)
                    for byte in chunk.value():
                        received.append(byte)
                assert_equal(
                    received,
                    expected,
                    encoding + "/" + payload + "/" + String(size),
                )
                assert_true(response.is_closed())
                assert_true(not response.read_chunk(size))


def test_decoder_truncated_streams() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for encoding in ["gzip", "deflate", "raw-deflate", "multi", "multi-raw"]:
        var url = "/encoded?kind=" + encoding + "&fragment=1&truncate=1"
        var response = client.stream("GET", url)
        var caught = False
        try:
            _ = response.read()
        except error:
            assert_equal(error.kind, ErrorKind.DecodeError, encoding)
            assert_equal(error.method.value(), "GET")
            assert_equal(error.url.value(), getenv("REQ_TEST_URL") + url)
            caught = True
        assert_true(caught, encoding)
        assert_true(response.is_closed())
        assert_equal(client.get("/echo").status_code, 200)


def test_decoder_concatenated_gzip_members() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    for size in [1, 5, 20]:
        var response = client.stream(
            "GET", "/encoded?kind=gzip&fragment=1&concatenate=1"
        )
        var received = Bytes()
        while True:
            var chunk = response.read_chunk(size)
            if not chunk:
                break
            for byte in chunk.value():
                received.append(byte)
        assert_equal(received, encode_utf8("test 123test 123"))
        assert_true(response.is_closed())


def test_decoder_raw_deflate_header_ambiguity() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var expected = String()
    for _ in range(156):
        expected += "A"
    for size in [1, 7, 65536]:
        var response = client.stream(
            "GET", "/encoded?kind=ambiguous-deflate&fragment=1"
        )
        var received = Bytes()
        while True:
            var chunk = response.read_chunk(size)
            if not chunk:
                break
            for byte in chunk.value():
                received.append(byte)
        assert_equal(received, encode_utf8(expected))


comptime TEST_FUNCTIONS = __functions_in_module()
