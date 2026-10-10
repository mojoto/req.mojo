"""Owned synchronous request and response callbacks."""

from std.memory import ArcPointer
from ._owned import _OwnedObject
from ._models import Request, Response
from ._exceptions import HTTPError


def _invoke[
    T: Movable & Deinitable, Value: Movable & Deinitable
](mut owner: _OwnedObject, mut value: Value) raises HTTPError:
    comptime assert conforms_to(T, def(mut Value) raises HTTPError -> None)
    owner.pointer[T]()[](value)


struct _HookState[Value: Movable & Deinitable](Movable):
    var owner: _OwnedObject
    var invoke: def(
        mut _OwnedObject, mut Self.Value
    ) thin raises HTTPError -> None

    def __init__[
        Handler: def(mut Self.Value) raises HTTPError -> None
    ](out self, var handler: Handler):
        self.owner = _OwnedObject(handler^)
        self.invoke = _invoke[Handler, Self.Value]


struct _Hook[Value: Movable & Deinitable](ImplicitlyCopyable):
    var _state: ArcPointer[_HookState[Self.Value]]

    @implicit
    def __init__[
        Handler: def(mut Self.Value) raises HTTPError -> None
    ](out self, var handler: Handler):
        self._state = ArcPointer(_HookState[Self.Value](handler^))

    def __call__(self, mut value: Self.Value) raises HTTPError:
        self._state[].invoke(self._state[].owner, value)


comptime RequestHook = _Hook[Request]
comptime ResponseHook = _Hook[Response]


struct EventHooks(ImplicitlyCopyable):
    var request: List[RequestHook]
    var response: List[ResponseHook]

    def __init__(out self, *, copy: Self):
        self.request = copy.request.copy()
        self.response = copy.response.copy()

    def __init__(
        out self,
        *,
        request: List[RequestHook] = List[RequestHook](),
        response: List[ResponseHook] = List[ResponseHook](),
    ):
        self.request = request.copy()
        self.response = response.copy()
