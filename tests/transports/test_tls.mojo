"""TLS tests."""
from req import Client, ErrorKind
from req._utils import percent_encode
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def test_tls_no_verify() raises:
    var client = Client(verify=False)
    assert_equal(
        client.get(getenv("REQ_TEST_TLS_URL") + "/echo").status_code, 200
    )


def test_tls_ca() raises:
    var client = Client(ca_file=getenv("REQ_TEST_CA_FILE"))
    assert_equal(
        client.get(getenv("REQ_TEST_TLS_URL") + "/echo").status_code, 200
    )


def test_tls_missing_ca() raises:
    var client = Client(ca_file=getenv("REQ_TEST_CA_FILE") + ".missing")
    var caught = False
    try:
        _ = client.get(getenv("REQ_TEST_TLS_URL") + "/echo")
    except error:
        assert_equal(error.kind, ErrorKind.TLSError)
        caught = True
    assert_true(caught)


def test_tls_hostname_mismatch() raises:
    var target = getenv("REQ_TEST_TLS_URL").replace("localhost", "127.0.0.1")
    var client = Client(ca_file=getenv("REQ_TEST_CA_FILE"))
    var caught = False
    try:
        _ = client.get(target + "/echo")
    except error:
        assert_equal(error.kind, ErrorKind.TLSError)
        caught = True
    assert_true(caught)


def test_tls_verification() raises:
    var url = getenv("REQ_TEST_TLS_URL")
    var client = Client()
    var caught = False
    try:
        _ = client.get(url + "/echo")
    except error:
        assert_equal(error.kind, ErrorKind.TLSError)
        caught = True
    assert_true(caught)
    var trusted = Client(ca_file=getenv("REQ_TEST_CA_FILE"))
    assert_equal(trusted.get(url + "/echo").status_code, 200)
    var insecure = Client(verify=False)
    assert_equal(insecure.get(url + "/echo").status_code, 200)
    with assert_raises():
        _ = Client(verify=False, ca_file=getenv("REQ_TEST_CA_FILE"))


def test_downgrade_redirect_rejected() raises:
    var client = Client(
        ca_file=getenv("REQ_TEST_CA_FILE"), follow_redirects=True
    )
    var target = percent_encode(getenv("REQ_TEST_URL") + "/echo")
    var caught = False
    try:
        _ = client.get(getenv("REQ_TEST_TLS_URL") + "/redirect?to=" + target)
    except error:
        assert_equal(error.kind, ErrorKind.UnsafeRedirect)
        caught = True
    assert_true(caught)
