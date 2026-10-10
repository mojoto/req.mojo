"""Pool tests."""
import req
from req import Client, ErrorKind, Limits, Timeout
from std.math import inf, nan
from std.os import getenv
from std.time import sleep
from std.testing import assert_equal, assert_raises, assert_true


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


def test_keepalive_expiry_with_an_active_connection() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), limits=Limits(keepalive_expiry=0.1)
    )
    var active = client.stream("GET", "/bytes")
    var first = client.get("/echo").json()["connection"].int_value()
    assert_equal(client.get("/echo").json()["connection"].int_value(), first)
    sleep(0.2)
    assert_true(client.get("/echo").json()["connection"].int_value() != first)
    assert_equal(len(active.read()), 200000)


def test_keepalive_expiry_preserves_active_http2_peers() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_HTTP2_URL"),
        ca_file=getenv("REQ_TEST_CA_FILE"),
        http2=True,
        limits=Limits(keepalive_expiry=0.1),
    )
    var active = client.stream("GET", "/bytes")
    var connection = active.headers["X-Connection"]
    assert_equal(client.get("/echo").headers["X-Connection"], connection)
    sleep(0.2)
    assert_equal(client.get("/echo").headers["X-Connection"], connection)
    assert_equal(len(active.read()), 200000)


def test_keepalive_expiry_uses_each_connections_idle_time() raises:
    var client = Client(limits=Limits(keepalive_expiry=0.5))
    var url = getenv("REQ_TEST_URL") + "/echo"
    var other_url = getenv("REQ_TEST_OTHER_URL") + "/echo"
    var first = client.get(url).json()["connection"].int_value()
    sleep(0.35)
    var recent = client.get(other_url).json()["connection"].int_value()
    sleep(0.25)
    # Check the recent connection before a slow reconnect can also expire it.
    assert_equal(client.get(other_url).json()["connection"].int_value(), recent)
    assert_true(client.get(url).json()["connection"].int_value() != first)


def test_keepalive_expiry_disabled_with_an_active_connection() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"), limits=Limits(keepalive_expiry=None)
    )
    var active = client.stream("GET", "/bytes")
    var first = client.get("/echo").json()["connection"].int_value()
    sleep(0.2)
    assert_equal(client.get("/echo").json()["connection"].int_value(), first)
    assert_equal(len(active.read()), 200000)


def test_keepalive_expiry_preserves_unsent_bodies() raises:
    for http2 in [False, True]:
        var client = Client(
            http2=http2,
            ca_file=getenv("REQ_TEST_CA_FILE"),
            limits=Limits(keepalive_expiry=0.1),
        )
        var url = (
            getenv("REQ_TEST_HTTP2_URL" if http2 else "REQ_TEST_URL") + "/echo"
        )
        var active = client.stream(
            "GET", getenv("REQ_TEST_OTHER_URL") + "/bytes"
        )
        var first = client.get(url).json()["connection"].int_value()
        sleep(0.2)
        var chunks = List[req.Bytes]()
        chunks.append(req.encode_utf8("unsent"))
        var response = client.post(
            url, body=req.RequestBody.from_chunks(chunks)
        )
        assert_equal(response.json()["body"].string_value(), "unsent")
        var connection = response.json()["connection"].int_value()
        assert_true(connection != first)
        assert_equal(
            client.get(url).json()["connection"].int_value(), connection
        )
        assert_equal(len(active.read()), 200000)
