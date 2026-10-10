"""Streaming tests."""
import req
from req import (
    Bytes,
    Client,
    ErrorKind,
    Headers,
    Request,
    RequestBody,
    encode_utf8,
)
from std.ffi import c_int, external_call
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def test_file_upload_and_request_lifetime() raises:
    var body = RequestBody.from_file(getenv("REQ_TEST_UPLOAD_FILE"))
    assert_equal(body.content_length().value(), 65537)
    var request = Request(
        "PUT", getenv("REQ_TEST_URL") + "/echo-bytes", body=body
    )
    body.close()
    assert_true(body.is_closed())
    with assert_raises():
        _ = body.content_length()
    var client = Client()
    var response = client.send(request)
    var content = response.content()
    assert_equal(len(content), 65537)
    for i in range(len(content)):
        assert_equal(content[i], UInt8(i % 251))
    assert_equal(response.request.body.value().content_length().value(), 65537)
    assert_equal(
        req.post(
            getenv("REQ_TEST_URL") + "/echo-bytes",
            body=RequestBody.from_file(getenv("REQ_TEST_EMPTY_FILE")),
        ).content(),
        Bytes(),
    )
    with assert_raises():
        _ = RequestBody.from_file("/does/not/exist")


def test_chunked_upload_and_one_shot_replay() raises:
    var chunks = List[Bytes]()
    chunks.append(encode_utf8("hello "))
    chunks.append(Bytes())
    chunks.append(encode_utf8("world"))
    var body = RequestBody.from_chunks(chunks)
    assert_true(not body.content_length())
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post("/echo", body=body)
    assert_equal(response.json()["body"].string_value(), "hello world")
    assert_equal(
        response.json()["headers"]["Transfer-Encoding"].string_value(),
        "chunked",
    )
    var consumed = False
    try:
        _ = client.post("/echo", body=body)
    except error:
        consumed = error.kind == ErrorKind.StreamConsumed
    assert_true(consumed)
    var empty_chunks = List[Bytes]()
    assert_equal(
        client.post("/echo", body=RequestBody.from_chunks(empty_chunks))
        .json()["body"]
        .string_value(),
        "",
    )
    with assert_raises():
        _ = Request(
            "POST",
            getenv("REQ_TEST_URL"),
            body=RequestBody.from_chunks(chunks),
            headers=Headers({"Content-Length": "11"}),
        )


def test_file_mutation_is_an_upload_error() raises:
    var path = getenv("REQ_TEST_CHANGED_FILE")
    var body = RequestBody.from_file(path)
    assert_equal(
        external_call["truncate", c_int](path.as_c_string_span().ptr(), Int(1)),
        0,
    )
    var failed = False
    try:
        _ = req.post(getenv("REQ_TEST_URL") + "/echo-bytes", body=body)
    except error:
        failed = error.kind == ErrorKind.WriteError
    assert_true(failed)


def test_large_file_streaming_digest() raises:
    var response = req.post(
        getenv("REQ_TEST_URL") + "/upload-digest",
        body=RequestBody.from_file(getenv("REQ_TEST_LARGE_FILE")),
    )
    assert_equal(response.json()["size"].int_value(), 134217728)
    assert_equal(
        response.json()["sha256"].string_value(),
        "254bcc3fc4f27172636df4bf32de9f107f620d559b20d760197e452b97453917",
    )
