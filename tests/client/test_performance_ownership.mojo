"""Request ownership across response attachment and hook-driven redirects."""

from std.testing import assert_equal
from req import (
    Bytes,
    Client,
    EventHooks,
    Headers,
    HTTPError,
    MockTransport,
    Request,
    Response,
    ResponseHook,
    encode_utf8,
)


def test_response_retains_large_request_without_consuming_send_input() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(200, request=Request("GET", "http://other.test"))

    var body = Bytes(length=1048576, fill=120)
    var request = Request(
        "POST", "http://example.test/upload", content=body.copy()
    )
    var client = Client(transport=MockTransport(handler))
    var response = client.send(request)
    client.close()
    body[0] = 0
    request.content.value()[1048575] = 0
    assert_equal(response.request.method, "POST")
    assert_equal(String(response.request.url), "http://example.test/upload")
    assert_equal(len(response.request.content.value()), 1048576)
    assert_equal(response.request.content.value()[0], UInt8(120))
    assert_equal(response.request.content.value()[1048575], UInt8(120))
    assert_equal(request.content.value()[0], UInt8(120))


def test_response_hook_request_mutation_does_not_change_redirect_upload() raises:
    def handler(request: Request) raises HTTPError -> Response:
        if request.url.path() == "/first":
            return Response(
                307, request=request, headers=Headers({"Location": "/final"})
            )
        return Response(200, request=request, content=request.content.value())

    def after(mut response: Response) raises HTTPError:
        if response.status_code == 307:
            response.request.content = encode_utf8("hook mutation")

    var client = Client(
        transport=MockTransport(handler),
        follow_redirects=True,
        event_hooks=EventHooks(response=[ResponseHook(after)]),
    )
    var response = client.post(
        "http://example.test/first", content=encode_utf8("original")
    )
    assert_equal(response.request.content.value(), encode_utf8("original"))
    assert_equal(response.content(), encode_utf8("original"))
    assert_equal(
        response.history[0].request.content.value(),
        encode_utf8("hook mutation"),
    )
