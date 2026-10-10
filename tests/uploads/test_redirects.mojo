"""Redirects tests."""
from req import Bytes, Client, ErrorKind, RequestBody, encode_utf8
from std.os import getenv
from std.testing import assert_equal, assert_true


def test_upload_redirect_replay_and_method_change() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    for code in [307, 308]:
        var response = client.post(
            "/redirect?code=" + String(code) + "&to=/echo-bytes",
            body=RequestBody.from_file(getenv("REQ_TEST_UPLOAD_FILE")),
        )
        assert_equal(len(response.content()), 65537)
        var chunks = List[Bytes]()
        chunks.append(encode_utf8("once"))
        var failed = False
        try:
            _ = client.post(
                "/redirect?code=" + String(code),
                body=RequestBody.from_chunks(chunks),
            )
        except error:
            failed = error.kind == ErrorKind.StreamConsumed
        assert_true(failed)
    var chunks = List[Bytes]()
    chunks.append(encode_utf8("replay"))
    var repeat = client.post(
        "/redirect?code=307",
        body=RequestBody.from_chunks(
            chunks, known_length=True, replayable=True
        ),
    )
    assert_equal(repeat.json()["body"].string_value(), "replay")
    var changed = client.post(
        "/redirect?code=303", body=RequestBody.from_chunks(chunks)
    )
    assert_equal(changed.json()["method"].string_value(), "GET")
    assert_equal(changed.json()["body"].string_value(), "")
