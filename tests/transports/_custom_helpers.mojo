"""Instrumented streams and transports for lifecycle tests."""

from std.memory import ArcPointer
from req import (
    BaseTransport,
    SyncByteStream,
    ByteStream,
    Bytes,
    Request,
    Response,
    Headers,
    Timeout,
    HTTPError,
    ErrorKind,
    encode_utf8,
)


struct State(Movable):
    var calls: Int
    var closes: Int
    var stream_closes: Int
    var destroys: Int
    var requests: List[Request]
    var read_timeout: Optional[Float64]

    def __init__(out self):
        self.calls = 0
        self.closes = 0
        self.stream_closes = 0
        self.destroys = 0
        self.requests = List[Request]()
        self.read_timeout = None


struct Chunks(SyncByteStream):
    var state: ArcPointer[State]
    var parts: List[Bytes]
    var index: Int
    var offset: Int
    var fail: Bool

    def __init__(
        out self,
        state: ArcPointer[State],
        var parts: List[Bytes],
        *,
        fail: Bool = False,
    ):
        self.state = state
        self.parts = parts^
        self.index = 0
        self.offset = 0
        self.fail = fail

    def read_chunk(mut self, size: Int) raises HTTPError -> Optional[Bytes]:
        if self.fail:
            raise HTTPError(ErrorKind.ReadError, "Injected stream failure")
        while self.index < len(self.parts):
            if self.offset == len(self.parts[self.index]):
                self.index += 1
                self.offset = 0
                continue
            var end = min(self.offset + size, len(self.parts[self.index]))
            var result = Bytes()
            result.extend(Span(self.parts[self.index])[self.offset : end])
            self.offset = end
            return result^
        return None

    def close(mut self):
        self.state[].stream_closes += 1

    def __deinit__(deinit self):
        self.state[].destroys += 1


struct RecordingTransport(BaseTransport):
    var state: ArcPointer[State]
    var streaming: Bool
    var fail: Bool

    def __init__(
        out self,
        state: ArcPointer[State],
        *,
        streaming: Bool = False,
        fail: Bool = False,
    ):
        self.state = state
        self.streaming = streaming
        self.fail = fail

    def handle_request(
        mut self, request: Request, timeout: Timeout
    ) raises HTTPError -> Response:
        self.state[].calls += 1
        self.state[].requests.append(request)
        self.state[].read_timeout = timeout.read
        if self.fail:
            raise HTTPError(
                ErrorKind.ConnectError, "Injected transport failure"
            )
        var headers = Headers()
        if request.url.path() == "/redirect":
            headers.set("Location", "/done")
            headers.add("Set-Cookie", "session=active; Path=/")
            return Response(303, request=request, headers=headers)
        if self.streaming:
            return Response.from_byte_stream(
                ByteStream(
                    Chunks(self.state, [encode_utf8("one"), encode_utf8("two")])
                ),
                request,
            )
        return Response(
            200,
            request=request,
            content=request.content.value().copy() if request.content else encode_utf8(
                "mock"
            ),
        )

    def close(mut self):
        self.state[].closes += 1
