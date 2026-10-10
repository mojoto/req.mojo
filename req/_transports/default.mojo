"""Ownership-safe handles for the native pull-based transport."""

from std.ffi import c_int
from std.memory import Pointer, ArcPointer
from .._exceptions import HTTPError, ErrorKind
from .._types import Bytes
from .._config import Timeout, Limits
from .._body import RequestBody
from .._utils import decode_utf8
from ._library import NativePool, Pool


def new_pool(limits: Limits = Limits()) raises HTTPError -> Pool:
    return ArcPointer(NativePool(limits))


def close_pool(handle: Pool):
    if handle:
        handle.value()[].close(handle.value()[].handle)


def release_pool(mut handle: Pool):
    handle = None


def _seconds(value: Optional[Float64]) -> Float64:
    return value.value() if value else -1.0


struct CurlStream(Movable):
    var handle: Int
    var owns_pool: Pool
    var _pool: Pool
    var _upload_body: Optional[RequestBody]

    def __init__(
        out self,
        pool: Pool,
        var method: String,
        var url: String,
        var headers: String,
        content: Optional[Bytes],
        timeout: Timeout,
        verify: Bool,
        ca_file: Optional[String],
        *,
        body: Optional[RequestBody] = None,
        var proxy: String = "",
        var no_proxy: String = "",
        var ca_path: String = "",
    ) raises HTTPError:
        self.owns_pool = None
        self._pool = pool
        self._upload_body = body
        # The native constructor copies the upload before returning.
        var empty = Bytes()
        var raw_pointer = (
            content.value().unsafe_ptr() if content else empty.unsafe_ptr()
        )
        var ca = ca_file.value() if ca_file else String()
        self.handle = pool.value()[].transfer_new(
            pool.value()[].handle,
            Int(method.as_c_string_span().ptr()),
            Int(url.as_c_string_span().ptr()),
            Int(headers.as_c_string_span().ptr()),
            Int(raw_pointer),
            len(content.value()) if content else 0,
            c_int(Bool(content)),
            _seconds(timeout.connect),
            _seconds(timeout.read),
            _seconds(timeout.write),
            c_int(verify),
            Int(ca.as_c_string_span().ptr()),
            body.value()._handle() if body else 0,
            _seconds(timeout.pool),
            Int(proxy.as_c_string_span().ptr()),
            Int(no_proxy.as_c_string_span().ptr()),
            Int(ca_path.as_c_string_span().ptr()),
        )
        if not self.handle:
            raise HTTPError(
                ErrorKind.ConnectError, "Cannot initialize HTTP request"
            )
        var error = Int(self._pool.value()[].transfer_headers(self.handle))
        if error >= 0:
            self.close()
            raise HTTPError(
                ErrorKind(error),
                "HTTP transport failed",
                method=method,
                url=url,
            )

    def __deinit__(deinit self):
        if self.handle:
            self._pool.value()[].free(self.handle)
        if self.owns_pool:
            close_pool(self.owns_pool)
            release_pool(self.owns_pool)

    def headers(self) raises HTTPError -> String:
        var address = self._pool.value()[].header_data(self.handle)
        var size = self._pool.value()[].header_size(self.handle)
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
        var count = self._pool.value()[].read(
            self.handle, Int(buffer.unsafe_ptr()), len(buffer)
        )
        if count < 0:
            self.close()
            raise HTTPError(ErrorKind(-count - 1), "HTTP response read failed")
        if count == 0:
            self.close()
        return count

    def close(mut self):
        if self.handle:
            self._pool.value()[].free(self.handle)
        self.handle = 0
        if self.owns_pool:
            close_pool(self.owns_pool)
            release_pool(self.owns_pool)
        self._pool = None
        self._upload_body = None
