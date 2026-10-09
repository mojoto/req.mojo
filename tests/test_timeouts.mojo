from std.testing import TestSuite, assert_equal, assert_true
from std.os import getenv
from req import Client, Timeout, ErrorKind, encode_utf8, Bytes


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


def main() raises:
    TestSuite.discover_tests[__functions_in_module()]().run()
