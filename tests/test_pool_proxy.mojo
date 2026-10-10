from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from std.math import inf, nan
import req
from req import Client, Limits, Timeout, ErrorKind


def test_limits_and_pool_timeout_configuration() raises:
    assert_equal(Limits().max_connections.value(), 100)
    assert_equal(Timeout().pool.value(), 5.0)
    assert_true(not Timeout.disabled().pool)
    with assert_raises():
        _ = Limits(max_connections=0)
    with assert_raises():
        _ = Limits(max_keepalive_connections=-1)
    for value in [-1.0, inf[DType.float64](), nan[DType.float64]()]:
        with assert_raises():
            _ = Limits(keepalive_expiry=value)
    with assert_raises():
        _ = Timeout(pool=0.0)
    var limits = Limits()
    limits.max_connections = -1
    with assert_raises():
        _ = Client(limits=limits)


def test_pool_exhaustion_release_and_timeout_kind() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), limits=Limits(max_connections=1)
    )
    var first = client.stream("GET", "/bytes")
    var timed_out = False
    try:
        _ = client.get(
            "/echo",
            timeout=Timeout(connect=0.01, read=0.01, write=0.01, pool=0.08),
        )
    except error:
        timed_out = error.kind == ErrorKind.PoolTimeout
    assert_true(timed_out)
    first.close()
    assert_equal(client.get("/echo").status_code, 200)
    var second = client.stream("GET", "/bytes")
    client.close()
    with assert_raises():
        _ = second.read_chunk(1)


def test_pool_allows_multiple_active_responses() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), limits=Limits(max_connections=2)
    )
    var first = client.stream("GET", "/bytes")
    var second = client.stream("GET", "/bytes")
    assert_equal(len(first.read()), 200000)
    assert_equal(len(second.read()), 200000)
    assert_equal(client.get("/echo").status_code, 200)


def test_keepalive_limit_and_expiry() raises:
    var url = getenv("REQ_TEST_URL") + "/echo"
    var retained = Client(limits=Limits(max_keepalive_connections=1))
    var one = retained.get(url).json()["connection"].int_value()
    assert_equal(retained.get(url).json()["connection"].int_value(), one)
    var other_url = getenv("REQ_TEST_OTHER_URL") + "/echo"
    var two = retained.get(other_url).json()["connection"].int_value()
    var reused_one = retained.get(url).json()["connection"].int_value() == one
    var reused_two = (
        retained.get(other_url).json()["connection"].int_value() == two
    )
    assert_true(not (reused_one and reused_two))
    for limits in [
        Limits(max_keepalive_connections=0),
        Limits(keepalive_expiry=0.0),
    ]:
        var client = Client(limits=limits)
        var first = client.get(url).json()["connection"].int_value()
        assert_true(client.get(url).json()["connection"].int_value() != first)
    var expiring = Client(limits=Limits(keepalive_expiry=0.03))
    var initial = expiring.get(url).json()["connection"].int_value()
    _ = req.get(getenv("REQ_TEST_OTHER_URL") + "/slow-headers")
    assert_true(expiring.get(url).json()["connection"].int_value() != initial)


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


comptime TEST_FUNCTIONS = __functions_in_module()


def test_pool_timeout_preserves_an_unsent_body() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), limits=Limits(max_connections=1)
    )
    var active = client.stream("GET", "/bytes")
    var chunks = List[req.Bytes]()
    chunks.append(req.encode_utf8("unsent"))
    var body = req.RequestBody.from_chunks(chunks)
    var failed = False
    try:
        _ = client.post("/echo", body=body, timeout=Timeout(pool=0.03))
    except error:
        failed = error.kind == ErrorKind.PoolTimeout
    assert_true(failed)
    active.close()
    assert_equal(
        client.post("/echo", body=body).json()["body"].string_value(), "unsent"
    )


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


def test_keepalive_limit_after_concurrent_streams() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        limits=Limits(max_connections=2, max_keepalive_connections=1),
    )
    var first = client.stream("GET", "/echo")
    var second = client.stream("GET", "/echo")
    _ = first.read()
    _ = second.read()
    var one = first.json()["connection"].int_value()
    var two = second.json()["connection"].int_value()
    assert_true(one != two)
    var next_first = client.stream("GET", "/echo")
    var next_second = client.stream("GET", "/echo")
    _ = next_first.read()
    _ = next_second.read()
    var a = next_first.json()["connection"].int_value()
    var b = next_second.json()["connection"].int_value()
    assert_true(not ((a == one and b == two) or (a == two and b == one)))
