from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from req import Client, ErrorKind
from req._utils import percent_encode


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


comptime TEST_FUNCTIONS = __functions_in_module()
