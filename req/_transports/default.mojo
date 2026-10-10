"""Ownership-safe handles for the native pull-based transport."""

from std.ffi import external_call, c_int
from std.memory import Pointer
from .._exceptions import HTTPError, ErrorKind
from .._types import Bytes
from .._config import Timeout
from .._utils import decode_utf8


def new_pool() raises HTTPError -> Int:
    var handle = external_call["req_pool_new", Int]()
    if not handle:
        raise HTTPError(
            ErrorKind.ConnectError, "Cannot initialize HTTP transport"
        )
    return handle


def close_pool(handle: Int):
    external_call["req_pool_close", NoneType](handle)


def release_pool(handle: Int):
    external_call["req_pool_release", NoneType](handle)


def _seconds(value: Optional[Float64]) -> Float64:
    return value.value() if value else -1.0


struct CurlStream(Movable):
    var handle: Int
    var owns_pool: Int

    def __init__(
        out self,
        pool: Int,
        var method: String,
        var url: String,
        var headers: String,
        content: Optional[Bytes],
        timeout: Timeout,
        verify: Bool,
        ca_file: Optional[String],
    ) raises HTTPError:
        self.owns_pool = 0
        # The native constructor copies the upload before returning.
        var empty = Bytes()
        var body = (
            content.value().unsafe_ptr() if content else empty.unsafe_ptr()
        )
        var ca = ca_file.value() if ca_file else String()
        self.handle = external_call["req_transfer_new", Int](
            pool,
            method.as_c_string_span().ptr(),
            url.as_c_string_span().ptr(),
            headers.as_c_string_span().ptr(),
            body,
            len(content.value()) if content else 0,
            c_int(Bool(content)),
            _seconds(timeout.connect),
            _seconds(timeout.read),
            _seconds(timeout.write),
            c_int(verify),
            ca.as_c_string_span().ptr(),
        )
        if not self.handle:
            raise HTTPError(
                ErrorKind.ConnectError, "Cannot initialize HTTP request"
            )
        var error = Int(
            external_call["req_transfer_headers", c_int](self.handle)
        )
        if error >= 0:
            self.close()
            raise HTTPError(
                ErrorKind(error),
                "HTTP transport failed",
                method=method,
                url=url,
            )

    def __deinit__(deinit self):
        external_call["req_transfer_free", NoneType](self.handle)
        if self.owns_pool:
            close_pool(self.owns_pool)
            release_pool(self.owns_pool)

    def headers(self) raises HTTPError -> String:
        var address = external_call["req_transfer_header_data", Int](
            self.handle
        )
        var size = external_call["req_transfer_header_size", Int](self.handle)
        var pointer = Pointer[UInt8, ImmutAnyOrigin](
            unsafe_from_address=address
        )
        var bytes = Bytes(capacity=size)
        bytes.extend(Span(unsafe_ptr=pointer, length=size))
        return decode_utf8(bytes)

    def read_chunk(
        mut self, max_bytes: Int
    ) raises HTTPError -> Optional[Bytes]:
        if not self.handle:
            raise HTTPError(ErrorKind.StreamClosed, "Response stream is closed")
        var size = min(max_bytes, 16384)
        var buffer = Bytes(length=size, fill=0)
        var count = self._read_into(buffer)
        if count == 0:
            return None
        buffer.resize(count, 0)
        return buffer^

    def _read_into(mut self, mut buffer: Bytes) raises HTTPError -> Int:
        if not self.handle:
            raise HTTPError(ErrorKind.StreamClosed, "Response stream is closed")
        if not buffer:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Read buffer must not be empty"
            )
        var count = external_call["req_transfer_read", Int](
            self.handle, buffer.unsafe_ptr(), len(buffer)
        )
        if count < 0:
            self.close()
            raise HTTPError(ErrorKind(-count - 1), "HTTP response read failed")
        if count == 0:
            self.close()
        return count

    def close(mut self):
        external_call["req_transfer_free", NoneType](self.handle)
        self.handle = 0
        if self.owns_pool:
            close_pool(self.owns_pool)
            release_pool(self.owns_pool)
            self.owns_pool = 0
