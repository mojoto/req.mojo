"""Adapted HTTPX multipart scenarios verified over the native HTTP transport."""

from std.os import getenv
from std.testing import assert_equal, assert_true
from req import (
    Client,
    Headers,
    UploadFile,
    RequestBody,
    QueryParams,
    encode_utf8,
)


def check_explicit_boundary(header: String) raises:
    var files = List[UploadFile]()
    files.append(UploadFile.from_bytes("file", encode_utf8("<file content>")))
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/echo-bytes", files=files, headers=Headers({"content-type": header})
    )
    assert_equal(response.status_code, 200)
    assert_equal(response.request.headers["Content-Type"], header)
    assert_equal(
        response.text(),
        (
            '--+++\r\nContent-Disposition: form-data; name="file";'
            ' filename="upload"\r\nContent-Type:'
            " application/octet-stream\r\n\r\n<file content>\r\n--+++--\r\n"
        ),
    )


def test_explicit_boundary_wire() raises:
    check_explicit_boundary("multipart/form-data; boundary=+++")


def test_multipart_string_field_wire() raises:
    var files = List[UploadFile]()
    files.append(UploadFile.from_bytes("file", encode_utf8("<file content>")))
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/echo-bytes", data=QueryParams("text=abc"), files=files
    )
    var header = response.request.headers["Content-Type"]
    var boundary = String(header.split("boundary=")[1])
    assert_equal(response.status_code, 200)
    assert_equal(
        response.text(),
        "--"
        + boundary
        + '\r\nContent-Disposition: form-data; name="text"\r\n\r\nabc\r\n--'
        + boundary
        + '\r\nContent-Disposition: form-data; name="file";'
        ' filename="upload"\r\nContent-Type:'
        " application/octet-stream\r\n\r\n<file content>\r\n--"
        + boundary
        + "--\r\n",
    )


def test_bytes_file_wire_and_length() raises:
    var files = List[UploadFile]()
    files.append(
        UploadFile.from_bytes(
            "file",
            encode_utf8("<bytes content>"),
            filename="test.txt",
            content_type="text/plain",
        )
    )
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post(
        "/echo",
        files=files,
        headers=Headers(
            {"Content-Type": "multipart/form-data; boundary=BOUNDARY"}
        ),
    )
    var expected = (
        '--BOUNDARY\r\nContent-Disposition: form-data; name="file";'
        ' filename="test.txt"\r\nContent-Type: text/plain\r\n\r\n<bytes'
        " content>\r\n--BOUNDARY--\r\n"
    )
    var result = response.json()
    assert_equal(result["body"].string_value(), expected)
    assert_equal(
        result["headers"]["Content-Length"].string_value(),
        String(expected.byte_length()),
    )
    assert_equal(
        response.request.headers["Content-Type"],
        "multipart/form-data; boundary=BOUNDARY",
    )
    assert_true("Host" in result["headers"].to_string())


def test_file_offsets_restart_on_each_send() raises:
    var files = List[UploadFile]()
    files.append(UploadFile("file", getenv("REQ_TEST_UPLOAD_FILE")))
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var first = client.post(
        "/echo-bytes",
        files=files,
        headers=Headers(
            {"Content-Type": "multipart/form-data; boundary=BOUNDARY"}
        ),
    )
    var second = client.post(
        "/echo-bytes",
        files=files,
        headers=Headers(
            {"Content-Type": "multipart/form-data; boundary=BOUNDARY"}
        ),
    )
    assert_equal(first.content(), second.content())
    assert_true(len(first.content()) > 65537)


comptime TEST_FUNCTIONS = __functions_in_module()
