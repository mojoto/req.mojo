"""Callback ordering, mutation, ownership, and cleanup."""

from std.memory import ArcPointer
from std.testing import assert_equal, assert_true
from req import (
    Client,
    EventHooks,
    RequestHook,
    ResponseHook,
    MockTransport,
    Request,
    Response,
    HTTPError,
    ErrorKind,
    Headers,
    Auth,
    encode_utf8,
)
from tests.transports._custom_helpers import State, RecordingTransport


struct HookState(Movable):
    var events: List[String]
    var body: String
    var closed: Bool
    var unread: Bool

    def __init__(out self):
        self.events = List[String]()
        self.body = String()
        self.closed = False
        self.unread = False


def test_event_hooks_order_and_request_mutation() raises:
    var state = ArcPointer(HookState())

    def before(mut request: Request) raises HTTPError {var state}:
        state[].events.append("request")
        request.headers.set("X-Hook", "value")

    def before_second(mut request: Request) raises HTTPError {var state}:
        state[].events.append(request.headers["X-Hook"])

    def handler(request: Request) raises HTTPError {var state} -> Response:
        state[].events.append("transport")
        return Response(200, request=request)

    def after(mut response: Response) raises HTTPError {var state}:
        state[].events.append("response")
        response.headers.set("X-Response", "changed")

    def after_second(mut response: Response) raises HTTPError {var state}:
        state[].events.append(response.headers["X-Response"])

    var client = Client(
        transport=MockTransport(handler^),
        event_hooks=EventHooks(
            request=[RequestHook(before^), RequestHook(before_second^)],
            response=[ResponseHook(after^), ResponseHook(after_second^)],
        ),
    )
    var response = client.get("http://example.test")
    assert_equal(
        state[].events,
        ["request", "value", "transport", "response", "changed"],
    )
    assert_equal(response.headers["X-Response"], "changed")


def test_request_hook_receives_prepared_auth_and_cookies() raises:
    var state = ArcPointer(HookState())

    def before(mut request: Request) raises HTTPError {var state}:
        state[].events.append(request.headers["Authorization"])
        state[].events.append(request.headers["Cookie"])
        state[].events.append(request.headers["X-Client"])

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state),
        auth=Auth.bearer("token"),
        headers=Headers({"X-Client": "yes"}),
        event_hooks=EventHooks(request=[RequestHook(before^)]),
    )
    client.cookies.set("session", "value", domain="example.test")
    _ = client.get("http://example.test")
    assert_equal(state[].events, ["Bearer token", "session=value", "yes"])


def test_hooks_run_for_every_redirect() raises:
    var state = ArcPointer(HookState())

    def before(mut request: Request) raises HTTPError {var state}:
        state[].events.append(request.method + " " + request.url.path())

    def after(mut response: Response) raises HTTPError {var state}:
        state[].events.append(String(response.status_code))

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state),
        follow_redirects=True,
        event_hooks=EventHooks(
            request=[RequestHook(before^)], response=[ResponseHook(after^)]
        ),
    )
    _ = client.post("http://example.test/redirect", content=encode_utf8("body"))
    assert_equal(
        state[].events,
        ["POST /redirect", "303", "GET /done", "200"],
    )


def test_hooks_unfollowed_redirect_runs_once() raises:
    var state = ArcPointer(HookState())

    def after(mut response: Response) raises HTTPError {var state}:
        state[].events.append(String(response.status_code))

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state),
        event_hooks=EventHooks(response=[ResponseHook(after^)]),
    )
    _ = client.get("http://example.test/redirect")
    assert_equal(state[].events, ["303"])


def test_request_hook_error_prevents_send_and_later_hooks() raises:
    var state = ArcPointer(HookState())

    def fail(mut request: Request) raises HTTPError:
        raise HTTPError(ErrorKind.InvalidRequest, "Hook failure")

    def later(mut request: Request) raises HTTPError {var state}:
        state[].events.append("unexpected")

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state),
        event_hooks=EventHooks(
            request=[RequestHook(fail), RequestHook(later^)]
        ),
    )
    var caught = False
    try:
        _ = client.get("http://example.test/error")
    except error:
        caught = error.kind == ErrorKind.InvalidRequest
        assert_equal(error.url.value(), "http://example.test/error")
    assert_true(caught)
    assert_equal(transport_state[].calls, 0)
    assert_equal(len(state[].events), 0)


def test_request_hook_mutation_is_validated() raises:
    def before(mut request: Request) raises HTTPError:
        request.method = "bad method"

    var state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(state),
        event_hooks=EventHooks(request=[RequestHook(before)]),
    )
    var caught = False
    try:
        _ = client.get("http://example.test")
    except error:
        caught = error.kind == ErrorKind.InvalidRequest
    assert_true(caught)
    assert_equal(state[].calls, 0)


def test_response_hook_sees_unread_stream() raises:
    var state = ArcPointer(HookState())

    def after(mut response: Response) raises HTTPError {var state}:
        state[].closed = response.is_closed()
        try:
            _ = response.content()
        except error:
            state[].unread = error.kind == ErrorKind.StreamNotRead

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state, streaming=True),
        event_hooks=EventHooks(response=[ResponseHook(after^)]),
    )
    var response = client.get("http://example.test")
    assert_true(state[].unread)
    assert_true(not state[].closed)
    assert_equal(response.text(), "onetwo")


def test_response_hook_can_read_stream() raises:
    var state = ArcPointer(HookState())

    def after(mut response: Response) raises HTTPError {var state}:
        _ = response.read()
        state[].body = response.text()

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state, streaming=True),
        event_hooks=EventHooks(response=[ResponseHook(after^)]),
    )
    var response = client.stream("GET", "http://example.test")
    assert_equal(state[].body, "onetwo")
    assert_equal(response.content(), encode_utf8("onetwo"))
    assert_true(response.is_closed())
    assert_equal(transport_state[].stream_closes, 1)


def test_response_hook_error_closes_stream() raises:
    def after(mut response: Response) raises HTTPError:
        raise HTTPError(ErrorKind.HTTPStatusError, "Hook failure")

    var state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(state, streaming=True),
        event_hooks=EventHooks(response=[ResponseHook(after)]),
    )
    var caught = False
    try:
        _ = client.stream("PUT", "http://example.test/error")
    except error:
        caught = error.kind == ErrorKind.HTTPStatusError
        assert_equal(error.method.value(), "PUT")
        assert_equal(error.url.value(), "http://example.test/error")
    assert_true(caught)
    assert_equal(state[].stream_closes, 1)


def test_response_hook_failure_stops_later_hooks() raises:
    var state = ArcPointer(HookState())

    def fail(mut response: Response) raises HTTPError:
        raise HTTPError(ErrorKind.InvalidRequest, "stop")

    def later(mut response: Response) raises HTTPError {var state}:
        state[].events.append("unexpected")

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state),
        event_hooks=EventHooks(
            response=[ResponseHook(fail), ResponseHook(later^)]
        ),
    )
    try:
        _ = client.get("http://example.test")
    except:
        pass
    assert_equal(len(state[].events), 0)


def test_response_hook_status_check() raises:
    def handler(request: Request) raises HTTPError -> Response:
        return Response(404, request=request)

    def after(mut response: Response) raises HTTPError:
        response.raise_for_status()

    var client = Client(
        transport=MockTransport(handler),
        event_hooks=EventHooks(response=[ResponseHook(after)]),
    )
    var caught = False
    try:
        _ = client.get("http://example.test")
    except error:
        caught = error.kind == ErrorKind.HTTPStatusError
        assert_equal(error.status_code.value(), 404)
    assert_true(caught)


def test_event_hooks_configuration_is_copied() raises:
    var state = ArcPointer(HookState())

    def before(mut request: Request) raises HTTPError {var state}:
        state[].events.append("called")

    var config = EventHooks(request=[RequestHook(before^)])
    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state), event_hooks=config
    )
    config.request.clear()
    _ = client.get("http://example.test")
    assert_equal(len(config.request), 0)
    assert_equal(state[].events, ["called"])


def test_event_hooks_can_be_updated_on_client() raises:
    var state = ArcPointer(HookState())

    def before(mut request: Request) raises HTTPError {var state}:
        state[].events.append(request.url.path())

    var transport_state = ArcPointer(State())
    var client = Client(transport=RecordingTransport(transport_state))
    _ = client.get("http://example.test/first")
    client.event_hooks.request.append(RequestHook(before^))
    _ = client.get("http://example.test/second")
    client.event_hooks.request.clear()
    _ = client.get("http://example.test/third")
    assert_equal(state[].events, ["/second"])


def test_transport_error_does_not_run_response_hooks() raises:
    var state = ArcPointer(HookState())

    def after(mut response: Response) raises HTTPError {var state}:
        state[].events.append("unexpected")

    var transport_state = ArcPointer(State())
    var client = Client(
        transport=RecordingTransport(transport_state, fail=True),
        event_hooks=EventHooks(response=[ResponseHook(after^)]),
    )
    try:
        _ = client.get("http://example.test")
    except:
        pass
    assert_equal(len(state[].events), 0)
