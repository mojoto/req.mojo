"""Proxies tests."""
import req
from req import Client, ErrorKind
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def test_http_proxy_authentication_and_origin_headers() raises:
    var response = req.get(
        getenv("REQ_TEST_URL") + "/echo", proxy=getenv("REQ_TEST_PROXY")
    )
    assert_equal(
        response.json()["headers"]["X-Test-Proxy"].string_value(), "forwarded"
    )
    with assert_raises():
        _ = response.json()["headers"]["Proxy-Authorization"]
    var direct = req.get(getenv("REQ_TEST_URL") + "/echo")
    with assert_raises():
        _ = direct.json()["headers"]["X-Test-Proxy"]
    var incorrect = getenv("REQ_TEST_PROXY").replace("user:pass", "user:wrong")
    assert_equal(
        req.get(getenv("REQ_TEST_URL") + "/echo", proxy=incorrect).status_code,
        407,
    )
    for proxy in [
        "",
        "socks5://localhost:9000",
        "http://",
        "http://localhost/path",
        "http://localhost#fragment",
        "http://localhost\r\nInjected: yes",
    ]:
        with assert_raises():
            _ = Client(proxy=proxy)


def test_https_connect_proxy_and_tls_validation() raises:
    var target = getenv("REQ_TEST_TLS_URL") + "/echo"
    var proxied = req.get(
        target,
        proxy=getenv("REQ_TEST_PROXY"),
        ca_file=getenv("REQ_TEST_CA_FILE"),
    )
    assert_equal(proxied.status_code, 200)
    assert_equal(proxied.http_version, "HTTP/1.1")
    with assert_raises():
        _ = proxied.json()["headers"]["Proxy-Authorization"]
    var rejected = False
    try:
        _ = req.get(target, proxy=getenv("REQ_TEST_PROXY"))
    except error:
        rejected = error.kind == ErrorKind.TLSError
    assert_true(rejected)


def test_trust_env_proxy_no_proxy_and_ca() raises:
    var env = Client(trust_env=True)
    var http = env.get(getenv("REQ_TEST_URL") + "/echo")
    assert_equal(
        http.json()["headers"]["X-Test-Proxy"].string_value(), "forwarded"
    )
    var tls = env.get(getenv("REQ_TEST_TLS_URL") + "/echo")
    assert_equal(tls.status_code, 200)
    var direct = env.get(
        getenv("REQ_TEST_URL").replace("127.0.0.1", "localhost") + "/echo"
    )
    with assert_raises():
        _ = direct.json()["headers"]["X-Test-Proxy"]
    var explicit = Client(proxy=getenv("REQ_TEST_PROXY"), trust_env=True)
    assert_equal(
        explicit.get(
            getenv("REQ_TEST_URL").replace("127.0.0.1", "localhost") + "/echo"
        )
        .json()["headers"]["X-Test-Proxy"]
        .string_value(),
        "forwarded",
    )
    with assert_raises():
        _ = req.get(getenv("REQ_TEST_TLS_URL") + "/echo")


def test_https_proxy_certificate_verification() raises:
    var proxy = getenv("REQ_TEST_TLS_PROXY")
    var response = req.get(
        getenv("REQ_TEST_URL") + "/echo",
        proxy=proxy,
        ca_file=getenv("REQ_TEST_CA_FILE"),
    )
    assert_equal(
        response.json()["headers"]["X-Test-Proxy"].string_value(), "forwarded"
    )
    var tunnel = req.get(
        getenv("REQ_TEST_TLS_URL") + "/echo",
        proxy=proxy,
        ca_file=getenv("REQ_TEST_CA_FILE"),
    )
    assert_equal(tunnel.status_code, 200)
    with assert_raises():
        _ = req.get(getenv("REQ_TEST_URL") + "/echo", proxy=proxy)
