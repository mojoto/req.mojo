"""HTTP/2 tests."""
from ..transports._http2_helpers import _client
from req import (
    Bytes,
    Client,
    ErrorKind,
    Limits,
    QueryParams,
    RequestBody,
    Timeout,
    UploadFile,
    encode_utf8,
)
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def test_http2_uploads_and_redirect_replay() raises:
    var client = Client(http2=True, ca_file=getenv("REQ_TEST_CA_FILE"))
    var url = getenv("REQ_TEST_HTTP2_URL")
    var file = client.post(
        url + "/upload-digest",
        body=RequestBody.from_file(getenv("REQ_TEST_UPLOAD_FILE")),
    )
    assert_equal(file.http_version, "HTTP/2")
    assert_equal(file.json()["size"].int_value(), 65537)
    var chunks = client.post(
        url + "/echo",
        body=RequestBody.from_chunks(
            List[Bytes]([encode_utf8("hello"), encode_utf8(" HTTP/2")])
        ),
    )
    assert_equal(chunks.json()["body"].string_value(), "hello HTTP/2")
    with assert_raises():
        _ = chunks.json()["headers"]["transfer-encoding"]
    var files = List[UploadFile](
        [
            UploadFile.from_bytes(
                "file", encode_utf8("content"), filename="test.txt"
            )
        ]
    )
    var multipart = client.post(
        url + "/echo", files=files, data=QueryParams({"name": "Mojo"})
    )
    var text = multipart.json()["body"].string_value()
    assert_true(
        'name="name"' in text
        and "Mojo" in text
        and 'filename="test.txt"' in text
    )
    var redirected = client.post(
        url + "/redirect?code=307",
        body=RequestBody.from_bytes(encode_utf8("replayed")),
        follow_redirects=True,
    )
    assert_equal(redirected.http_version, "HTTP/2")
    assert_equal(redirected.json()["body"].string_value(), "replayed")
    var dropped = client.post(
        url + "/redirect?code=303",
        content=encode_utf8("drop"),
        follow_redirects=True,
    )
    assert_equal(dropped.json()["method"].string_value(), "GET")
    assert_equal(dropped.json()["size"].int_value(), 0)


def test_http2_upload_obeys_window_updates_and_preserves_bytes() raises:
    var client = _client()
    var response = client.post(
        "/flow-upload",
        body=RequestBody.from_file(getenv("REQ_TEST_UPLOAD_FILE")),
    )
    assert_equal(response.json()["size"].int_value(), 65537)
    assert_equal(
        response.json()["sha256"].string_value(),
        "237356e18b503616912abb8ffaed3a72591e397d4ac294c4637917d48a3f529d",
    )
    assert_true(response.json()["window_updates"].int_value() > 1)
    assert_equal(response.http_version, "HTTP/2")


def test_http2_refused_stream_replays_file_upload() raises:
    var client = _client()
    var response = client.post(
        "/refused-once?file",
        body=RequestBody.from_file(getenv("REQ_TEST_UPLOAD_FILE")),
    )
    assert_equal(response.json()["size"].int_value(), 65537)
    assert_equal(
        response.json()["sha256"].string_value(),
        "237356e18b503616912abb8ffaed3a72591e397d4ac294c4637917d48a3f529d",
    )
    assert_equal(response.http_version, "HTTP/2")


def test_http2_refused_stream_does_not_replay_one_shot_body() raises:
    var client = _client()
    for known_length in [False, True]:
        var body = RequestBody.from_chunks(
            List[Bytes]([encode_utf8("once")]), known_length=known_length
        )
        var caught = False
        try:
            _ = client.post(
                "/refused-once?one-shot-" + String(known_length), body=body
            )
        except error:
            assert_equal(error.kind, ErrorKind.StreamConsumed)
            caught = True
        assert_true(caught)
        assert_equal(client.get("/echo").http_version, "HTTP/2")


def test_http2_pool_timeout_does_not_consume_unsent_upload() raises:
    var client = Client(
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        base_url=getenv("REQ_TEST_HTTP2_LIMITED_URL"),
        limits=Limits(max_connections=1),
    )
    var first = client.stream("GET", "/bytes")
    var body = RequestBody.from_chunks(List[Bytes]([encode_utf8("unsent")]))
    var caught = False
    try:
        _ = client.post("/echo", body=body, timeout=Timeout(pool=0.05))
    except error:
        assert_equal(error.kind, ErrorKind.PoolTimeout)
        caught = True
    assert_true(caught)
    first.close()
    assert_equal(
        client.post("/echo", body=body).json()["body"].string_value(), "unsent"
    )


def test_http2_refused_stream_replays_finite_chunks() raises:
    var client = _client()
    for known_length in [False, True]:
        var response = client.post(
            "/refused-once?replayable-" + String(known_length),
            body=RequestBody.from_chunks(
                List[Bytes]([encode_utf8("hello"), encode_utf8(" HTTP/2")]),
                known_length=known_length,
                replayable=True,
            ),
        )
        assert_equal(response.json()["body"].string_value(), "hello HTTP/2")
        assert_equal(response.json()["size"].int_value(), 12)
        assert_equal(response.http_version, "HTTP/2")
