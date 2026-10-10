"""Exercise installed modules and native loading from outside the checkout."""

import req
from std.os import getenv
from std.testing import assert_equal, assert_true


def surviving_response(url: String) raises -> req.Response:
    var client = req.Client()
    return client.stream("GET", url)


def mock_response(request: req.Request) raises req.HTTPError -> req.Response:
    return req.Response(
        200, request=request, content=req.encode_utf8("offline")
    )


def main() raises:
    var offline = req.Client(transport=req.MockTransport(mock_response))
    assert_equal(offline.get("http://offline.test").text(), "offline")
    offline.close()
    if getenv("REQ_EXPECT_HTTP2_UNAVAILABLE"):
        try:
            _ = req.Client(http2=True)
        except error:
            assert_equal(error.kind, req.ErrorKind.InvalidRequest)
            assert_true("HTTP/2 support" in error.message)
            return
        raise Error("Expected an unavailable HTTP/2 backend error")
    if getenv("REQ_EXPECT_LOAD_ERROR"):
        try:
            var client = req.Client()
        except error:
            assert_equal(error.kind, req.ErrorKind.ConnectError)
            assert_true(
                "Req" in error.message or "REQ_NATIVE_LIB" in error.message
            )
            return
        raise Error("Expected a native library loading error")

    var url = getenv("REQ_TEST_URL")
    var response = req.get(url + "/echo")
    assert_equal(response.status_code, 200)
    assert_equal(response.json()["method"].string_value(), "GET")

    var client = req.Client()
    var payload = req.JSONValue.object()
    payload.set("name", req.JSONValue("Mojo"))
    var posted = client.post(url + "/echo", json=payload)
    assert_equal(posted.json()["body"].string_value(), '{"name":"Mojo"}')
    var uploaded = client.post(
        url + "/upload-digest",
        body=req.RequestBody.from_file(getenv("REQ_TEST_UPLOAD_FILE")),
    )
    assert_equal(uploaded.json()["size"].int_value(), 65537)
    var files = List[req.UploadFile]()
    files.append(req.UploadFile.from_bytes("file", req.encode_utf8("packaged")))
    assert_equal(
        client.post(url + "/multipart", files=files)
        .json()["parts"][0]["text"]
        .string_value(),
        "packaged",
    )
    client.close()
    var configured = req.Client(
        proxy=getenv("REQ_TEST_PROXY"),
        limits=req.Limits(max_connections=1),
        timeout=req.Timeout(pool=1.0),
    )
    assert_equal(
        configured.get(url + "/echo")
        .json()["headers"]["X-Test-Proxy"]
        .string_value(),
        "forwarded",
    )
    configured.close()

    var http2 = req.Client(http2=True, ca_file=getenv("REQ_TEST_CA_FILE"))
    var negotiated = http2.get(getenv("REQ_TEST_HTTP2_URL") + "/echo")
    assert_equal(negotiated.http_version, "HTTP/2")
    assert_equal(negotiated.status_code, 200)
    http2.close()

    # The response retains its pool even after the local Client is destroyed.
    var streamed = surviving_response(url + "/chunked")
    _ = streamed.read()
    assert_equal(streamed.text(), "hello world")
    print("Req package HTTP/2, JSON, upload, proxy, and streaming tests passed")
