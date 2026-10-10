"""Single-request transports and deterministic response handlers."""

from std.memory import ArcPointer
from .._owned import _OwnedObject
from .._models import Request, Response
from .._config import Timeout
from .._exceptions import HTTPError, ErrorKind


trait BaseTransport(Deinitable, Movable):
    def handle_request(
        mut self, request: Request, timeout: Timeout
    ) raises HTTPError -> Response:
        ...

    def close(mut self):
        ...


def _handle[
    T: BaseTransport
](
    mut owner: _OwnedObject, request: Request, timeout: Timeout
) raises HTTPError -> Response:
    return owner.pointer[T]()[].handle_request(request, timeout)


def _close[T: BaseTransport](mut owner: _OwnedObject):
    owner.pointer[T]()[].close()


struct _TransportState(Movable):
    var owner: _OwnedObject
    var handle: def(
        mut _OwnedObject, Request, Timeout
    ) thin raises HTTPError -> Response
    var close_transport: def(mut _OwnedObject) thin -> None
    var closed: Bool

    def __init__[T: BaseTransport](out self, var value: T):
        self.owner = _OwnedObject(value^)
        self.handle = _handle[T]
        self.close_transport = _close[T]
        self.closed = False


struct Transport(ImplicitlyCopyable):
    var _state: Optional[ArcPointer[_TransportState]]

    def __init__(out self):
        self._state = None

    @implicit
    def __init__[T: BaseTransport](out self, var value: T):
        self._state = ArcPointer(_TransportState(value^))

    def handle_request(
        mut self, request: Request, timeout: Timeout = Timeout()
    ) raises HTTPError -> Response:
        if self.is_closed():
            raise HTTPError(ErrorKind.ClientClosed, "Transport is closed")
        request.validate()
        try:
            return self._state.value()[].handle(
                self._state.value()[].owner, request, timeout
            )
        except error:
            error.method = request.method
            error.url = String(request.url)
            raise error

    def close(mut self):
        if self._state and not self._state.value()[].closed:
            self._state.value()[].closed = True
            self._state.value()[].close_transport(self._state.value()[].owner)

    def is_closed(self) -> Bool:
        return not self._state or self._state.value()[].closed


def _mock_handle[
    Handler: Movable & Deinitable
](mut owner: _OwnedObject, request: Request) raises HTTPError -> Response:
    comptime if conforms_to(Handler, def(Request) raises HTTPError -> Response):
        return owner.pointer[Handler]()[](request)
    else:
        raise HTTPError(ErrorKind.InvalidRequest, "Invalid mock handler")


struct _MockHandler(BaseTransport):
    var owner: _OwnedObject
    var handle: def(mut _OwnedObject, Request) thin raises HTTPError -> Response

    def __init__[
        Handler: def(Request) raises HTTPError -> Response
    ](out self, var handler: Handler):
        self.owner = _OwnedObject(handler^)
        self.handle = _mock_handle[Handler]

    def handle_request(
        mut self, request: Request, timeout: Timeout
    ) raises HTTPError -> Response:
        return self.handle(self.owner, request)

    def close(mut self):
        pass


struct MockTransport(BaseTransport):
    var _transport: Transport

    def __init__[
        Handler: (def(Request) raises HTTPError -> Response)
    ](out self, var handler: Handler):
        self._transport = Transport(_MockHandler(handler^))

    def handle_request(
        mut self, request: Request, timeout: Timeout = Timeout()
    ) raises HTTPError -> Response:
        return self._transport.handle_request(request, timeout)

    def close(mut self):
        self._transport.close()

    def is_closed(self) -> Bool:
        return self._transport.is_closed()
