"""Replay-aware request bodies with bounded native file reads."""

from std.ffi import OwnedDLHandle, c_int
from std.memory import ArcPointer
from ._types import Bytes
from ._exceptions import HTTPError, ErrorKind
from ._transports._library import _load_library, _symbol


struct _NativeBody(Movable):
    var library: OwnedDLHandle
    var handle: Int
    var free: def(Int) thin abi("C") -> NoneType
    var add_bytes: def(Int, Int, Int) thin abi("C") -> c_int
    var add_file: def(Int, Int) thin abi("C") -> c_int
    var append: def(Int, Int) thin abi("C") -> c_int
    var length: def(Int) thin abi("C") -> Int

    def __init__(
        out self, known_length: Bool, replayable: Bool
    ) raises HTTPError:
        self.library = _load_library()
        self.free = _symbol[type_of(self.free)](self.library, "req_body_free")
        self.add_bytes = _symbol[type_of(self.add_bytes)](
            self.library, "req_body_bytes"
        )
        self.add_file = _symbol[type_of(self.add_file)](
            self.library, "req_body_file"
        )
        self.append = _symbol[type_of(self.append)](
            self.library, "req_body_append"
        )
        self.length = _symbol[type_of(self.length)](
            self.library, "req_body_length"
        )
        var create = _symbol[def(c_int, c_int) thin abi("C") -> Int](
            self.library, "req_body_new"
        )
        self.handle = create(c_int(known_length), c_int(replayable))
        if not self.handle:
            raise HTTPError(
                ErrorKind.WriteError, "Cannot initialize request body"
            )

    def __deinit__(deinit self):
        self.free(self.handle)


def _check_body(error: c_int) raises HTTPError:
    if error >= 0:
        raise HTTPError(ErrorKind(Int(error)), "Cannot prepare request body")


struct RequestBody(ImplicitlyCopyable):
    var _source: Optional[ArcPointer[_NativeBody]]

    def __init__(
        out self, *, known_length: Bool = True, replayable: Bool = True
    ) raises HTTPError:
        self._source = ArcPointer(_NativeBody(known_length, replayable))

    @staticmethod
    def from_file(var path: String) raises HTTPError -> Self:
        if "\x00" in path:
            raise HTTPError(ErrorKind.InvalidRequest, "Invalid upload path")
        var body = Self()
        _check_body(
            body._source.value()[].add_file(
                body._handle(), Int(path.as_c_string_span().ptr())
            )
        )
        return body

    @staticmethod
    def from_bytes(content: Bytes) raises HTTPError -> Self:
        var body = Self()
        body._add(content)
        return body

    @staticmethod
    def from_chunks(
        chunks: List[Bytes],
        *,
        known_length: Bool = False,
        replayable: Bool = False,
    ) raises HTTPError -> Self:
        var body = Self(known_length=known_length, replayable=replayable)
        for chunk in chunks:
            body._add(chunk)
        return body

    def content_length(self) raises HTTPError -> Optional[Int]:
        var handle = self._handle()
        var size = self._source.value()[].length(handle)
        return size if size >= 0 else None

    def is_closed(self) -> Bool:
        return not Bool(self._source)

    def close(mut self):
        self._source = None

    def _handle(self) raises HTTPError -> Int:
        if not self._source:
            raise HTTPError(ErrorKind.StreamClosed, "Request body is closed")
        return self._source.value()[].handle

    def _add(self, content: Bytes) raises HTTPError:
        var handle = self._handle()
        _check_body(
            self._source.value()[].add_bytes(
                handle, Int(content.unsafe_ptr()), len(content)
            )
        )

    def _append(self, other: Self) raises HTTPError:
        var handle = self._handle()
        _check_body(self._source.value()[].append(handle, other._handle()))
