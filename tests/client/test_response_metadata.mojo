"""Redirect history, prepared next requests, cookies, and elapsed time."""

from std.memory import ArcPointer
from std.os import getenv
from std.time import sleep
from std.testing import assert_equal, assert_true, assert_raises
from req import (
    Client,
    MockTransport,
    Request,
    Response,
    ResponseHistory,
    Headers,
    Auth,
    RequestBody,
    EventHooks,
    RequestHook,
    ResponseHook,
    HTTPError,
    ErrorKind,
    ByteStream,
    encode_utf8,
)
from tests.transports._custom_helpers import State, Chunks, RecordingTransport


def _chain(request: Request) raises HTTPError -> Response:
    if request.url.path() == "/first":
        return Response(
            302,
            request=request,
            headers=Headers(
                {"Location": "/second", "Set-Cookie": "first=one; Path=/"}
            ),
            content=encode_utf8("first body"),
        )
    if request.url.path() == "/second":
        return Response(
            303,
            request=request,
            headers=Headers(
                {"Location": "/end", "Set-Cookie": "second=two; Path=/"}
            ),
            content=encode_utf8("second body"),
        )
    return Response(
        200,
        request=request,
        headers=Headers({"Set-Cookie": "final=three; Path=/"}),
        content=encode_utf8("final body"),
    )


def test_response_history_full_chain_and_prefixes() raises:
    var client = Client(transport=MockTransport(_chain), follow_redirects=True)
    var response = client.get("http://example.test/first")
    assert_equal(response.status_code, 200)
    assert_equal(len(response.history), 2)
    assert_equal(response.history[0].status_code, 302)
    assert_equal(response.history[1].status_code, 303)
    assert_equal(response.history[0].text(), "first body")
    assert_equal(response.history[1].text(), "second body")
    assert_true(response.history[0].is_closed())
    assert_true(response.history[1].is_closed())
    assert_equal(len(response.history[0].history), 0)
    assert_equal(len(response.history[1].history), 1)
    assert_equal(response.history[1].history[0].text(), "first body")
    assert_equal(String(response.history[0].url), "http://example.test/first")
    assert_equal(String(response.url), "http://example.test/end")
    assert_true(not response.next_request)
    assert_true(not response.history[0].next_request)


def test_response_history_indexing_and_iteration() raises:
    var client = Client(transport=MockTransport(_chain), follow_redirects=True)
    var response = client.get("http://example.test/first")
    assert_equal(response.history[-1].status_code, 303)
    assert_equal(response.history[-2].status_code, 302)
    for index in [2, -3]:
        with assert_raises():
            _ = response.history[index].status_code
    var codes = List[Int]()
    for previous in response.history:
        codes.append(previous.status_code)
    assert_equal(codes, [302, 303])


def _detached_history() raises HTTPError -> ResponseHistory:
    var client = Client(transport=MockTransport(_chain), follow_redirects=True)
    var response = client.get("http://example.test/first")
    client.close()
    return response.history


def test_response_history_survives_response_and_client() raises:
    var history = _detached_history()
    assert_equal(history[0].text(), "first body")
    assert_equal(history[1].history[0].text(), "first body")
    assert_equal(history[-1].request.url.path(), "/second")


def test_response_history_empty_without_redirects() raises:
    var client = Client(transport=MockTransport(_chain), follow_redirects=True)
    var response = client.get("http://example.test/end")
    assert_equal(len(response.history), 0)
    assert_true(not response.next_request)


def test_response_next_request_unfollowed_and_manual_send() raises:
    var client = Client(transport=MockTransport(_chain))
    var response = client.get("http://example.test/first")
    assert_equal(len(response.history), 0)
    assert_true(response.next_request)
    assert_equal(response.next_request.value().url.path(), "/second")
    assert_equal(response.next_request.value().headers["Cookie"], "first=one")
    var next_response = client.send(response.next_request.value())
    assert_equal(next_response.status_code, 303)
    assert_equal(next_response.next_request.value().url.path(), "/end")
    var final = client.send(next_response.next_request.value())
    assert_equal(final.text(), "final body")
    assert_equal(len(final.history), 0)


def test_response_next_request_method_and_body_matrix() raises:
    for code in [301, 302, 303, 307, 308]:
        var status = code

        def handler(request: Request) raises HTTPError {var status} -> Response:
            return Response(
                status, request=request, headers=Headers({"Location": "/next"})
            )

        for method in ["GET", "HEAD", "POST", "PUT"]:
            var client = Client(transport=MockTransport(handler))
            var content: Optional[List[UInt8]] = None
            if method != "HEAD":
                content = encode_utf8("body")
            var response = client.request(
                method,
                "http://example.test/start",
                content=content,
                headers=Headers({"Content-Type": "text/plain"}),
            )
            var rewritten = (code == 303 and method != "HEAD") or (
                code in [301, 302] and method == "POST"
            )
            assert_equal(
                response.next_request.value().method,
                "GET" if rewritten else method,
            )
            if rewritten:
                assert_true(not response.next_request.value().content)
                assert_true(
                    "Content-Type" not in response.next_request.value().headers
                )
            elif method == "HEAD":
                assert_true(not response.next_request.value().content)
            else:
                assert_equal(
                    response.next_request.value().content.value(),
                    encode_utf8("body"),
                )


def test_response_next_request_preserves_upload_body() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(
            307, request=request, headers=Headers({"Location": "/next"})
        )

    var client = Client(transport=MockTransport(handler))
    var response = client.post(
        "http://example.test/start",
        body=RequestBody.from_bytes(encode_utf8("upload")),
    )
    assert_true(response.next_request.value().body)
    assert_equal(
        response.next_request.value().body.value().content_length().value(), 6
    )
    assert_equal(response.next_request.value().method, "POST")


def test_response_next_request_cross_origin_strips_credentials() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(
            302,
            request=request,
            headers=Headers({"Location": "http://other.test/next"}),
        )

    var client = Client(
        transport=MockTransport(handler), auth=Auth.bearer("secret")
    )
    var response = client.get(
        "http://example.test/start",
        headers=Headers({"Cookie": "private=value", "Host": "example.test"}),
    )
    assert_true("Authorization" not in response.next_request.value().headers)
    assert_true("Cookie" not in response.next_request.value().headers)
    assert_true("Host" not in response.next_request.value().headers)
    assert_equal(response.next_request.value().url.host(), "other.test")


def test_response_next_request_requires_redirect_location() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(302, request=request)

    var client = Client(transport=MockTransport(handler))
    var response = client.get("http://example.test")
    assert_true(not response.next_request)
    assert_equal(len(response.history), 0)


def test_response_next_request_unsafe_redirect_is_inspectable() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(
            302,
            request=request,
            headers=Headers({"Location": "http://example.test/next"}),
        )

    var client = Client(transport=MockTransport(handler))
    var response = client.get("https://example.test/start")
    assert_equal(response.next_request.value().url.scheme(), "http")
    var caught = False
    try:
        _ = client.get("https://example.test/start", follow_redirects=True)
    except error:
        caught = error.kind == ErrorKind.UnsafeRedirect
    assert_true(caught)


def test_response_cookies_are_per_response_snapshots() raises:
    var client = Client(transport=MockTransport(_chain), follow_redirects=True)
    var response = client.get("http://example.test/first")
    assert_equal(
        response.cookies.get("final", domain="example.test").value(), "three"
    )
    assert_true(not response.cookies.get("first", domain="example.test"))
    assert_equal(
        response.history[0].cookies.get("first", domain="example.test").value(),
        "one",
    )
    assert_equal(
        response.history[1]
        .cookies.get("second", domain="example.test")
        .value(),
        "two",
    )
    assert_true(
        not response.history[1].cookies.get("first", domain="example.test")
    )
    assert_equal(
        client.cookies.get("first", domain="example.test").value(), "one"
    )
    assert_equal(
        client.cookies.get("second", domain="example.test").value(), "two"
    )
    response.cookies.clear()
    assert_equal(
        client.cookies.get("final", domain="example.test").value(), "three"
    )


def test_response_cookies_duplicate_names_paths_and_invalid_domain() raises:
    var headers = Headers()
    headers.add("Set-Cookie", "name=one; Path=/")
    headers.add("Set-Cookie", "name=two; Path=/nested")
    headers.add("Set-Cookie", "bad=value; Domain=other.test")
    headers.add("Set-Cookie", "old=value; Max-Age=0")
    var response = Response(
        200,
        request=Request("GET", "http://example.test/nested"),
        headers=headers,
    )
    assert_equal(
        response.cookies.get("name", domain="example.test").value(), "one"
    )
    assert_equal(
        response.cookies.get(
            "name", domain="example.test", path="/nested"
        ).value(),
        "two",
    )
    assert_true(not response.cookies.get("bad", domain="other.test"))
    assert_true(not response.cookies.get("old", domain="example.test"))


def test_response_cookies_use_actual_outgoing_request() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(
            200,
            request=Request("GET", "http://other.test"),
            headers=Headers({"Set-Cookie": "cookie=value"}),
        )

    var client = Client(transport=MockTransport(handler))
    var response = client.get("http://example.test/")
    assert_equal(
        response.cookies.get("cookie", domain="example.test").value(), "value"
    )
    assert_true(not response.cookies.get("cookie", domain="other.test"))


def test_response_elapsed_cached_transport_is_available() raises:
    def handler(request: Request) raises HTTPError -> Response:
        sleep(0.01)
        return Response(200, request=request)

    var client = Client(transport=MockTransport(handler))
    var response = client.get("http://example.test")
    assert_true(response.elapsed() >= 0.008)
    var duration = response.elapsed()
    sleep(0.01)
    response.close()
    assert_equal(response.elapsed(), duration)


def test_response_elapsed_stream_read_and_close() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state, streaming=True))
    var response = client.stream("GET", "http://example.test")
    with assert_raises():
        _ = response.elapsed()
    sleep(0.01)
    _ = response.read()
    assert_true(response.elapsed() >= 0.008)
    var duration = response.elapsed()
    response.close()
    assert_equal(response.elapsed(), duration)


def test_response_elapsed_partial_stream_close() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state, streaming=True))
    var response = client.stream("GET", "http://example.test")
    _ = response.read_chunk(2)
    with assert_raises():
        _ = response.elapsed()
    response.close()
    assert_true(response.elapsed() >= 0.0)


def test_response_elapsed_iteration_completion() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state, streaming=True))
    var response = client.stream("GET", "http://example.test")
    var count = 0
    for chunk in response.iter_bytes(2):
        count += len(chunk)
    assert_equal(count, 6)
    assert_true(response.elapsed() >= 0.0)


def test_response_elapsed_read_failure_is_recorded() raises:
    var state = ArcPointer(State())

    def handler(request: Request) raises HTTPError {var state} -> Response:
        return Response.from_byte_stream(
            ByteStream(Chunks(state, [], fail=True)), request
        )

    var client = Client(transport=MockTransport(handler^))
    var response = client.stream("GET", "http://example.test")
    var caught = False
    try:
        _ = response.read_chunk()
    except error:
        caught = error.kind == ErrorKind.ReadError
    assert_true(caught)
    assert_true(response.elapsed() >= 0.0)


def test_response_elapsed_unbound_response_is_unavailable() raises:
    var response = Response(200, request=Request("GET", "http://example.test"))
    with assert_raises():
        _ = response.elapsed()
    response.close()
    with assert_raises():
        _ = response.elapsed()


def test_response_metadata_context_view() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state))
    var next_path: String
    var duration: Float64
    var cookie: String
    var history_size: Int
    with client.stream("GET", "http://example.test/redirect") as context:
        next_path = context.next_request.value().url.path()
        cookie = context.cookies.get("session", domain="example.test").value()
        history_size = len(context.history)
        _ = context.read()
        duration = context.elapsed()
    assert_equal(next_path, "/done")
    assert_equal(cookie, "active")
    assert_equal(history_size, 0)
    assert_true(duration >= 0.0)


def test_response_hook_reads_and_records_elapsed() raises:
    var state = ArcPointer(State())

    def after(mut response: Response) raises HTTPError:
        _ = response.read()
        response.headers.set("X-Elapsed", String(response.elapsed()))

    var client = Client(
        transport=RecordingTransport(state, streaming=True),
        event_hooks=EventHooks(response=[ResponseHook(after)]),
    )
    var response = client.stream("GET", "http://example.test")
    assert_true("X-Elapsed" in response.headers)
    assert_true(response.elapsed() >= 0.0)


def test_response_native_redirect_history_and_next_request() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"), follow_redirects=True)
    var response = client.get("/redirect-chain?count=3")
    assert_equal(response.text(), "finished")
    assert_equal(len(response.history), 3)
    assert_equal(len(response.history[2].history), 2)
    for previous in response.history:
        assert_true(previous.is_closed())
        assert_true(previous.elapsed() >= 0.0)
        assert_equal(previous.text(), "")
    var unfollowed = client.get("/redirect-cookie", follow_redirects=False)
    assert_equal(
        unfollowed.next_request.value().headers["Cookie"], "session=active"
    )
    assert_equal(
        unfollowed.cookies.get("session", domain="127.0.0.1").value(), "active"
    )


def test_response_native_elapsed_includes_body_read() raises:
    var client = Client(base_url=getenv("REQ_TEST_URL"))
    var response = client.stream("GET", "/slow-body")
    with assert_raises():
        _ = response.elapsed()
    _ = response.read()
    assert_true(response.elapsed() >= 0.25)


def test_response_http2_redirect_history_and_elapsed() raises:
    var client = Client(
        base_url=getenv("REQ_TEST_HTTP2_URL"),
        http2=True,
        ca_file=getenv("REQ_TEST_CA_FILE"),
        follow_redirects=True,
    )
    var response = client.get("/redirect")
    assert_equal(len(response.history), 1)
    assert_equal(response.history[0].http_version, "HTTP/2")
    assert_true(response.history[0].elapsed() >= 0.0)
    assert_true(response.elapsed() >= 0.0)
    assert_true(response.history[0].is_closed())


def test_response_history_reads_redirect_body_keeps_final_stream_open() raises:
    var state = ArcPointer(State())

    def handler(request: Request) raises HTTPError {var state} -> Response:
        var redirected = request.url.path() == "/start"
        return Response.from_byte_stream(
            ByteStream(
                Chunks(
                    state,
                    [
                        encode_utf8(
                            "redirect body" if redirected else "final body"
                        )
                    ],
                )
            ),
            request,
            status_code=302 if redirected else 200,
            headers=Headers({"Location": "/end"}) if redirected else Headers(),
        )

    var client = Client(
        transport=MockTransport(handler^), follow_redirects=True
    )
    var response = client.stream("GET", "http://example.test/start")
    assert_equal(len(response.history), 1)
    assert_equal(response.history[0].text(), "redirect body")
    assert_true(response.history[0].is_closed())
    assert_true(response.history[0].elapsed() >= 0.0)
    assert_true(not response.is_closed())
    assert_equal(state[].stream_closes, 1)
    with assert_raises():
        _ = response.elapsed()
    _ = response.read()
    assert_equal(response.text(), "final body")
    assert_equal(state[].stream_closes, 2)


def test_response_redirect_limit_closes_every_stream() raises:
    var state = ArcPointer(State())

    def handler(request: Request) raises HTTPError {var state} -> Response:
        return Response.from_byte_stream(
            ByteStream(Chunks(state, [encode_utf8("body")])),
            request,
            status_code=302,
            headers=Headers({"Location": "/loop"}),
        )

    var client = Client(
        transport=MockTransport(handler^),
        follow_redirects=True,
        max_redirects=1,
    )
    var caught = False
    try:
        _ = client.get("http://example.test/loop")
    except error:
        caught = error.kind == ErrorKind.TooManyRedirects
    assert_true(caught)
    assert_equal(state[].stream_closes, 2)


def test_response_invalid_redirect_location_closes_stream() raises:
    var state = ArcPointer(State())

    def handler(request: Request) raises HTTPError {var state} -> Response:
        return Response.from_byte_stream(
            ByteStream(Chunks(state, [encode_utf8("body")])),
            request,
            status_code=302,
            headers=Headers({"Location": "ftp://example.test/file"}),
        )

    var client = Client(transport=MockTransport(handler^))
    var caught = False
    try:
        _ = client.get("http://example.test/start")
    except error:
        caught = error.kind == ErrorKind.InvalidURL
    assert_true(caught)
    assert_equal(state[].stream_closes, 1)


def test_response_next_request_uses_modified_location_from_hook() raises:
    def after(mut response: Response) raises HTTPError:
        response.headers.set("Location", "/modified")

    var client = Client(
        transport=MockTransport(_chain),
        event_hooks=EventHooks(response=[ResponseHook(after)]),
    )
    var response = client.get("http://example.test/first")
    assert_equal(response.next_request.value().url.path(), "/modified")


def test_response_elapsed_legacy_chunks_finish_at_eof() raises:
    var state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(state, streaming=True))
    var response = client.stream("GET", "http://example.test")
    while response.read_chunk(1):
        pass
    assert_true(response.elapsed() >= 0.0)
    assert_true(response.is_closed())
