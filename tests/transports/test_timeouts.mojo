"""Timeouts tests."""
from req import Bytes, Client, ErrorKind, Timeout
from std.os import getenv
from std.testing import assert_equal, assert_true


def test_send_timeout_override() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        timeout=Timeout(connect=1.0, read=0.05, write=1.0),
    )
    var request = client.build_request("GET", "/slow-body")
    var response = client.send(request, timeout=Timeout.disabled())
    assert_equal(response.text(), "partrest")
    var caught = False
    try:
        _ = client.send(request)
    except error:
        assert_equal(error.kind, ErrorKind.ReadTimeout)
        caught = True
    assert_true(caught)


def test_read_timeouts() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_URL"),
        timeout=Timeout(connect=1.0, read=0.1, write=1.0),
    )
    for path in ["/slow-headers", "/slow-body"]:
        var caught = False
        try:
            _ = client.get(path)
        except error:
            assert_equal(error.kind, ErrorKind.ReadTimeout)
            caught = True
        assert_true(caught)
    var response = client.get("/slow-body", timeout=Timeout.disabled())
    assert_equal(response.text(), "partrest")


def test_connect_and_write_timeouts() raises:
    var client = Client(
        timeout=Timeout(connect=0.1, read=1.0, write=0.1), verify=False
    )
    var caught = False
    try:
        _ = client.get(getenv("REQ_TEST_BLACKHOLE_URL"))
    except error:
        assert_equal(error.kind, ErrorKind.ConnectTimeout)
        caught = True
    assert_true(caught)
    var body = Bytes(capacity=16000000)
    for _ in range(16000000):
        body.append(65)
    caught = False
    try:
        _ = client.post(
            getenv("REQ_TEST_URL") + "/stall-upload", content=body.copy()
        )
    except error:
        assert_equal(error.kind, ErrorKind.WriteTimeout)
        caught = True
    assert_true(caught)
