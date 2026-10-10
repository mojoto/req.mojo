from std.testing import assert_equal, assert_true, assert_raises
from std.os import getenv
from std.ffi import external_call, c_int
import req
from req import (
    Client,
    Request,
    RequestBody,
    UploadFile,
    Headers,
    QueryParams,
    Bytes,
    ErrorKind,
    encode_utf8,
)


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


comptime TEST_FUNCTIONS = __functions_in_module()


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
