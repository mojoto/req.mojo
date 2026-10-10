"""Custom transport injection and stream ownership tests."""

from std.memory import ArcPointer
from std.os import getenv
from std.testing import assert_equal, assert_true, assert_raises
from req import (
    Client,
    ClientContext,
    Transport,
    MockTransport,
    HTTPTransport,
    Request,
    Response,
    Headers,
    Auth,
    Timeout,
    HTTPError,
    ErrorKind,
    ByteStream,
    encode_utf8,
)
from ._custom_helpers import State, Chunks, RecordingTransport


def _handler(request: Request) raises HTTPError -> Response:
    return Response(
        201,
        request=request,
        content=encode_utf8(request.method + " " + request.url.path()),
    )


def test_mock_transport_handler() raises:
    var client = Client(transport=MockTransport(_handler))
    var response = client.post(
        "http://example.test/items", content=encode_utf8("input")
    )
    assert_equal(response.status_code, 201)
    assert_equal(response.text(), "POST /items")
    assert_equal(response.request.content.value(), encode_utf8("input"))


def test_mock_transport_owned_closure() raises:
    var prefix = String("owned")

    def handler(request: Request) raises HTTPError {var prefix} -> Response:
        return Response(200, request=request, content=encode_utf8(prefix))

    var client = Client(transport=MockTransport(handler^))
    assert_equal(client.get("http://example.test").text(), "owned")


def test_transport_receives_merged_request() raises:
    var state = ArcPointer(State())
    var client = Client(
        base_url="http://example.test",
        headers=Headers({"X-Client": "yes"}),
        auth=Auth.bearer("token"),
        transport=RecordingTransport(state),
    )
    _ = client.get("/items", headers=Headers({"X-Request": "yes"}))
    assert_equal(state[].calls, 1)
    assert_equal(state[].requests[0].headers["X-Client"], "yes")
    assert_equal(state[].requests[0].headers["X-Request"], "yes")
    assert_equal(state[].requests[0].headers["Authorization"], "Bearer token")


def test_transport_request_timeout_override() raises:
    var state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(state), timeout=Timeout(read=3.0)
    )
    _ = client.get("http://example.test")
    assert_equal(state[].read_timeout.value(), 3.0)
    _ = client.get("http://example.test", timeout=Timeout(read=0.5))
    assert_equal(state[].read_timeout.value(), 0.5)


def test_transport_redirect_and_cookies() raises:
    var state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(state), follow_redirects=True
    )
    _ = client.post("http://example.test/redirect", content=encode_utf8("post"))
    assert_equal(state[].calls, 2)
    assert_equal(state[].requests[1].method, "GET")
    assert_equal(state[].requests[1].headers["Cookie"], "session=active")
    assert_true(not state[].requests[1].content)


def test_transport_close_is_idempotent() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state))
    client.close()
    client.close()
    assert_equal(state[].closes, 1)
    assert_true(client.is_closed())
    with assert_raises():
        _ = client.get("http://example.test")
    assert_equal(state[].calls, 0)


def test_transport_shared_close() raises:
    var state = ArcPointer(State())
    var transport = Transport(RecordingTransport(state))
    var first = Client(transport=transport)
    var second = Client(transport=transport)
    first.close()
    assert_true(second.is_closed())
    with assert_raises():
        _ = second.get("http://example.test")
    second.close()
    assert_equal(state[].closes, 1)


def test_transport_context_closes() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state))
    var text: String
    with client.context() as context:
        text = context.get("http://example.test").text()
    assert_equal(text, "mock")
    assert_equal(state[].closes, 1)


def test_transport_error_context() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state, fail=True))
    var caught = False
    try:
        _ = client.put("http://example.test/error")
    except error:
        assert_equal(error.kind, ErrorKind.ConnectError)
        assert_equal(error.method, "PUT")
        assert_equal(error.url.value(), "http://example.test/error")
        caught = True
    assert_true(caught)


def test_transport_validation_precedes_handler() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state))
    var request = Request("GET", "http://example.test")
    request.method = "bad method"
    with assert_raises():
        _ = client.send(request)
    assert_equal(state[].calls, 0)


def test_custom_stream_cached_response() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state, streaming=True))
    var response = client.get("http://example.test")
    assert_equal(response.text(), "onetwo")
    assert_true(response.is_closed())
    assert_equal(state[].stream_closes, 1)


def test_custom_stream_partial_consumption() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state, streaming=True))
    var response = client.stream("GET", "http://example.test")
    assert_equal(response.read_chunk(2).value(), encode_utf8("on"))
    with assert_raises():
        _ = response.read()
    response.close()
    response.close()
    assert_equal(state[].stream_closes, 1)


def test_custom_stream_failure_closes_and_attaches_request() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [], fail=True)),
        Request("GET", "http://example.test/error"),
    )
    var caught = False
    try:
        _ = response.read()
    except error:
        assert_equal(error.kind, ErrorKind.ReadError)
        assert_equal(error.method, "GET")
        assert_equal(error.url.value(), "http://example.test/error")
        caught = True
    assert_true(caught)
    assert_equal(state[].stream_closes, 1)


def _drop_stream(state: ArcPointer[State]):
    _ = ByteStream(Chunks(state, []))


def test_custom_stream_destruction_closes_once() raises:
    var state = ArcPointer(State())
    _drop_stream(state)
    assert_equal(state[].stream_closes, 1)
    assert_equal(state[].destroys, 1)


def test_http_transport_configured_injection() raises:
    var client = Client(
        transport=HTTPTransport(http2=True, ca_file=getenv("REQ_TEST_CA_FILE"))
    )
    assert_equal(
        client.get(getenv("REQ_TEST_HTTP2_URL") + "/echo").http_version,
        "HTTP/2",
    )


def test_mock_transport_attaches_actual_request() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(200, request=Request("POST", "http://other.test"))

    var client = Client(transport=MockTransport(handler))
    var response = client.get("http://example.test/actual")
    assert_equal(response.request.method, "GET")
    assert_equal(String(response.url), "http://example.test/actual")


def test_mock_transport_redirect_limit() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(
            302, request=request, headers=Headers({"Location": "/loop"})
        )

    var client = Client(
        transport=MockTransport(handler), follow_redirects=True, max_redirects=1
    )
    var caught = False
    try:
        _ = client.get("http://example.test/loop")
    except error:
        caught = error.kind == ErrorKind.TooManyRedirects
    assert_true(caught)


def test_mock_transport_cross_origin_strips_credentials() raises:
    def handler(request: Request) raises HTTPError -> Response:
        if request.url.host() == "example.test":
            return Response(
                302,
                request=request,
                headers=Headers({"Location": "http://other.test/final"}),
            )
        return Response(200, request=request)

    var client = Client(
        transport=MockTransport(handler),
        follow_redirects=True,
        auth=Auth.bearer("secret"),
    )
    var response = client.get(
        "http://example.test/start", headers=Headers({"Cookie": "secret=value"})
    )
    assert_true("Authorization" not in response.request.headers)
    assert_true("Cookie" not in response.request.headers)


def test_custom_stream_empty_parts_and_eof() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(
            Chunks(
                state, [encode_utf8(""), encode_utf8("abc"), encode_utf8("")]
            )
        ),
        Request("GET", "http://example.test"),
    )
    assert_equal(response.read_chunk(2).value(), encode_utf8("ab"))
    assert_equal(response.read_chunk(2).value(), encode_utf8("c"))
    assert_true(not response.read_chunk())
    assert_true(not response.read_chunk())
    assert_equal(state[].stream_closes, 1)


def test_custom_stream_invalid_chunk_size_does_not_consume() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [encode_utf8("abc")])),
        Request("GET", "http://example.test"),
    )
    with assert_raises():
        _ = response.read_chunk(0)
    assert_equal(response.read(), encode_utf8("abc"))


def test_custom_stream_closed_read_rejected() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [encode_utf8("abc")])),
        Request("GET", "http://example.test"),
    )
    response.close()
    with assert_raises():
        _ = response.read_chunk()
    assert_equal(state[].stream_closes, 1)
