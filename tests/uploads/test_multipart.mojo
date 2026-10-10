"""Multipart tests."""
import req
from req import (
    Bytes,
    Client,
    ErrorKind,
    Headers,
    QueryParams,
    Request,
    RequestBody,
    UploadFile,
    encode_utf8,
)
from std.os import getenv
from std.testing import assert_equal, assert_raises, assert_true


def multipart_boundary(header: String) raises:
    check_explicit_boundary(header)


def test_multipart_boundary_parameters() raises:
    multipart_boundary('multipart/form-data; boundary="+++"')
    multipart_boundary('multipart/form-data; boundary="+++" ;')
    multipart_boundary('multipart/form-data; boundary="+++"; charset=utf-8')
    multipart_boundary("multipart/form-data; boundary=+++")
    multipart_boundary("multipart/form-data; boundary=+++ ;")
    multipart_boundary("multipart/form-data; boundary=+++; charset=utf-8")
    multipart_boundary('multipart/form-data; charset=utf-8; boundary="+++"')
    multipart_boundary("multipart/form-data; charset=utf-8; boundary=+++")


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


def test_multipart_mixed_fields_files_and_custom_boundary() raises:
    var files = List[UploadFile]()
    files.append(
        UploadFile("asset", getenv("REQ_TEST_UPLOAD_FILE"), filename="data.bin")
    )
    files.append(
        UploadFile.from_bytes(
            "asset",
            encode_utf8("second"),
            filename="two.txt",
            content_type="text/plain",
        )
    )
    files.append(UploadFile("empty", getenv("REQ_TEST_EMPTY_FILE")))
    var response = req.post(
        getenv("REQ_TEST_URL") + "/multipart",
        data=QueryParams("tag=one&tag=two&blank="),
        files=files,
        headers=Headers(
            {"Content-Type": "multipart/form-data; boundary=custom-boundary"}
        ),
    )
    var result = response.json()
    assert_equal(result["parts_count"].int_value(), 6)
    assert_equal(result["parts"][0]["text"].string_value(), "one")
    assert_equal(result["parts"][1]["name"].string_value(), "tag")
    assert_equal(result["parts"][1]["text"].string_value(), "two")
    assert_equal(result["parts"][2]["size"].int_value(), 0)
    assert_equal(result["parts"][3]["filename"].string_value(), "data.bin")
    assert_equal(result["parts"][3]["size"].int_value(), 65537)
    assert_equal(
        result["parts"][4]["content_type"].string_value(), "text/plain"
    )
    assert_equal(result["parts"][4]["text"].string_value(), "second")
    assert_equal(result["parts"][5]["size"].int_value(), 0)
    assert_equal(
        result["headers"]["Content-Type"].string_value(),
        "multipart/form-data; boundary=custom-boundary",
    )
    var client = Client()
    var generated = client.build_request(
        "POST", getenv("REQ_TEST_URL"), files=files
    )
    assert_true(
        generated.headers["Content-Type"].startswith(
            "multipart/form-data; boundary="
        )
    )
    with assert_raises():
        _ = req.post(
            getenv("REQ_TEST_URL"), files=files, content=encode_utf8("conflict")
        )
    with assert_raises():
        _ = client.build_request(
            "POST",
            getenv("REQ_TEST_URL"),
            files=files,
            headers=Headers(
                {"Content-Type": "multipart/form-data; boundary=bad boundary"}
            ),
        )
    with assert_raises():
        _ = UploadFile.from_bytes(
            "x", Bytes(), content_type="text/plain\r\nInjected: yes"
        )
    with assert_raises():
        _ = Request(
            "HEAD",
            getenv("REQ_TEST_URL"),
            body=RequestBody.from_file(getenv("REQ_TEST_EMPTY_FILE")),
        )


def test_multipart_chunked_and_redirect() raises:
    var chunks = List[Bytes]()
    chunks.append(encode_utf8("chunked file"))
    var files = List[UploadFile]()
    files.append(
        UploadFile('a"\r\n', RequestBody.from_chunks(chunks), filename='q".txt')
    )
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.post("/multipart", files=files)
    assert_equal(
        response.json()["parts"][0]["name"].string_value(), "a%22%0D%0A"
    )
    assert_equal(
        response.json()["parts"][0]["filename"].string_value(), "q%22.txt"
    )
    assert_equal(
        response.json()["parts"][0]["text"].string_value(), "chunked file"
    )
    assert_equal(
        response.json()["headers"]["Transfer-Encoding"].string_value(),
        "chunked",
    )
    var disk = List[UploadFile]()
    disk.append(UploadFile("asset", getenv("REQ_TEST_UPLOAD_FILE")))
    var redirected = client.post(
        "/redirect?code=307&to=/multipart", files=disk, follow_redirects=True
    )
    assert_equal(redirected.json()["parts"][0]["size"].int_value(), 65537)


def test_multipart_one_shot_aliases_are_consumed() raises:
    var chunks = List[Bytes]()
    chunks.append(encode_utf8("once"))
    var source = RequestBody.from_chunks(chunks)
    var files = List[UploadFile]()
    files.append(UploadFile("file", source))
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var request = client.build_request("POST", "/multipart", files=files)
    var alias = client.build_request("POST", "/multipart", files=files)
    assert_equal(client.send(request).status_code, 200)
    var failed = False
    try:
        _ = client.send(alias)
    except error:
        failed = error.kind == ErrorKind.StreamConsumed
    assert_true(failed)
    with assert_raises():
        _ = client.build_request("POST", "/multipart", files=files)


def test_multipart_boundary_validation() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var files = List[UploadFile]()
    files.append(UploadFile.from_bytes("x", encode_utf8("ok")))
    for value in [
        "",
        "!!!",
        "bad boundary",
        '"unclosed',
        'unclosed"',
        "one; boundary=two",
    ]:
        with assert_raises():
            _ = client.build_request(
                "POST",
                "/echo",
                files=files,
                headers=Headers(
                    {"Content-Type": "multipart/form-data; boundary=" + value}
                ),
            )
    var response = client.post(
        "/multipart",
        files=files,
        headers=Headers(
            {"Content-Type": 'multipart/form-data; boundary="a:b?c"'}
        ),
    )
    assert_equal(response.json()["parts"][0]["text"].string_value(), "ok")
