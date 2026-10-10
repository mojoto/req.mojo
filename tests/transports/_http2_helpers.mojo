"""Shared HTTP/2 fixture clients and failure assertions."""
from req import Client, ErrorKind, Limits, Response, Timeout
from std.os import getenv
from std.testing import assert_equal, assert_true


def _client(limits: Limits = Limits()) raises -> Client:
    return Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        base_url=getenv("REQ_TEST_HTTP2_URL"),
        limits=limits,
    )


def _fails(mut client: Client, path: String, kind: ErrorKind) raises:
    var caught = False
    try:
        _ = client.get(path, timeout=Timeout(1.0))
    except error:
        assert_true(error.kind in [kind, ErrorKind.ProtocolError], String(error))
        assert_equal(error.method, "GET")
        assert_true(path in error.url.value())
        caught = True
    assert_true(caught)
    assert_equal(client.get("/echo").http_version, "HTTP/2")


def _closed(mut response: Response) raises:
    var caught = False
    try:
        _ = response.read()
    except error:
        assert_equal(error.kind, ErrorKind.StreamClosed)
        caught = True
    assert_true(caught)
