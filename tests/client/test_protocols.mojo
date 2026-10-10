"""Protocols tests."""
from req import Client, ErrorKind
from req._transports._library import _load_library, _symbol
from std.ffi import c_int
from std.os import getenv
from std.testing import assert_equal, assert_true


def test_http_protocol_defaults_and_http1_only() raises:
    for explicit in [False, True]:
        var client = Client(ca_file=getenv("REQ_TEST_CA_FILE"))
        if explicit:
            client = Client(
                http1=True, http2=False, ca_file=getenv("REQ_TEST_CA_FILE")
            )
        assert_equal(
            client.get(getenv("REQ_TEST_HTTP2_URL") + "/echo").http_version,
            "HTTP/1.1",
        )


def test_http2_enabled_negotiates_actual_version() raises:
    var client = Client(http2=True, ca_file=getenv("REQ_TEST_CA_FILE"))
    var response = client.get(getenv("REQ_TEST_HTTP2_URL") + "/echo")
    assert_equal(response.http_version, "HTTP/2")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "GET")


def test_http2_enabled_falls_back_to_http1() raises:
    var client = Client(
        http1=True, http2=True, ca_file=getenv("REQ_TEST_CA_FILE")
    )
    for target in [getenv("REQ_TEST_TLS_URL"), getenv("REQ_TEST_URL")]:
        assert_equal(client.get(target + "/echo").http_version, "HTTP/1.1")


def test_http_protocols_disabled_is_invalid() raises:
    var caught = False
    try:
        _ = Client(http1=False, http2=False)
    except error:
        caught = error.kind == ErrorKind.InvalidRequest
    assert_true(caught)


def test_http2_only_has_no_silent_fallback() raises:
    var library = _load_library()
    var supported = _symbol[def() thin abi("C") -> c_int](
        library, "req_http2_supported"
    )
    if supported() < 2:
        var caught = False
        try:
            _ = Client(http1=False, http2=True)
        except error:
            caught = (
                error.kind == ErrorKind.InvalidRequest
                and "8.10" in error.message
            )
        assert_true(caught)
        return
    var client = Client(
        http1=False, http2=True, ca_file=getenv("REQ_TEST_CA_FILE")
    )
    assert_equal(
        client.get(getenv("REQ_TEST_HTTP2_URL") + "/echo").http_version,
        "HTTP/2",
    )
    var rejected = False
    var failure = ErrorKind.InvalidRequest
    try:
        _ = client.get(getenv("REQ_TEST_TLS_URL") + "/echo")
    except error:
        failure = error.kind
        # An HTTP/1-only peer can close during either the H2 preface write
        # or the response read. Both outcomes must reject the request.
        rejected = error.kind in [
            ErrorKind.TLSError,
            ErrorKind.ProtocolError,
            ErrorKind.ReadError,
            ErrorKind.WriteError,
        ]
    assert_true(rejected, String(failure))


def test_http2_redirect_can_negotiate_http1_at_other_origin() raises:
    var client = Client(http2=True, ca_file=getenv("REQ_TEST_CA_FILE"))
    var target = getenv("REQ_TEST_TLS_URL") + "/echo"
    var response = client.get(
        getenv("REQ_TEST_HTTP2_URL") + "/redirect?to=" + target,
        follow_redirects=True,
    )
    assert_equal(response.http_version, "HTTP/1.1")
    assert_equal(response.status_code, 200)


def test_http2_tls_configuration_and_environment_ca() raises:
    var insecure = Client(http2=True, verify=False)
    assert_equal(
        insecure.get(getenv("REQ_TEST_HTTP2_URL") + "/echo").http_version,
        "HTTP/2",
    )
    var environment = Client(http2=True, trust_env=True)
    assert_equal(
        environment.get(getenv("REQ_TEST_HTTP2_URL") + "/echo").http_version,
        "HTTP/2",
    )
