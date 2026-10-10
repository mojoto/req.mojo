"""Runtime-polymorphic, pull-based response streams."""

from std.memory import ArcPointer
from ._owned import _OwnedObject
from ._types import Bytes
from ._exceptions import HTTPError, ErrorKind


trait SyncByteStream(Deinitable, Movable):
    def read_chunk(
        mut self, max_bytes: Int
    ) raises HTTPError -> Optional[Bytes]:
        ...

    def read_raw_chunk(
        mut self, max_bytes: Int
    ) raises HTTPError -> Optional[Bytes]:
        return self.read_chunk(max_bytes)

    def close(mut self):
        ...


def _read[
    T: SyncByteStream
](mut owner: _OwnedObject, size: Int) raises HTTPError -> Optional[Bytes]:
    return owner.pointer[T]()[].read_chunk(size)


def _read_raw[
    T: SyncByteStream
](mut owner: _OwnedObject, size: Int) raises HTTPError -> Optional[Bytes]:
    return owner.pointer[T]()[].read_raw_chunk(size)


def _close[T: SyncByteStream](mut owner: _OwnedObject):
    owner.pointer[T]()[].close()


struct _StreamState(Movable):
    var owner: _OwnedObject
    var read: def(mut _OwnedObject, Int) thin raises HTTPError -> Optional[
        Bytes
    ]
    var read_raw: def(mut _OwnedObject, Int) thin raises HTTPError -> Optional[
        Bytes
    ]
    var close_stream: def(mut _OwnedObject) thin -> None
    var closed: Bool

    def __init__[T: SyncByteStream](out self, var source: T):
        self.owner = _OwnedObject(source^)
        self.read = _read[T]
        self.read_raw = _read_raw[T]
        self.close_stream = _close[T]
        self.closed = False

    def close(mut self):
        if not self.closed:
            self.closed = True
            self.close_stream(self.owner)

    def __deinit__(deinit self):
        self.close()


struct ByteStream(ImplicitlyCopyable):
    var _state: ArcPointer[_StreamState]

    def __init__[T: SyncByteStream](out self, var source: T):
        self._state = ArcPointer(_StreamState(source^))

    def read_chunk(
        mut self, max_bytes: Int, *, raw: Bool = False
    ) raises HTTPError -> Optional[Bytes]:
        if max_bytes <= 0:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Chunk size must be positive"
            )
        if self.is_closed():
            raise HTTPError(ErrorKind.StreamClosed, "Response stream is closed")
        try:
            var result = (
                self._state[]
                .read_raw(
                    self._state[].owner, max_bytes
                ) if raw else self._state[]
                .read(self._state[].owner, max_bytes)
            )
            if result and len(result.value()) > max_bytes:
                raise HTTPError(
                    ErrorKind.ProtocolError,
                    "Stream exceeded requested chunk size",
                )
            if not result:
                self.close()
            return result^
        except error:
            self.close()
            raise error

    def close(mut self):
        self._state[].close()

    def is_closed(self) -> Bool:
        return self._state[].closed
