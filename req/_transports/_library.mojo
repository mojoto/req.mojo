"""Load the packaged native bridge and retain it for active requests."""

from std.ffi import OwnedDLHandle, RTLD, c_int, c_size_t
from std.memory import ArcPointer, Pointer
from std.os import getenv
from std.sys import CompilationTarget
from .._config import Limits
from .._exceptions import HTTPError, ErrorKind


comptime _TransferNew = def(
    Int,
    Pointer[Int8, ImmutAnyOrigin],
    Pointer[Int8, ImmutAnyOrigin],
    Pointer[Int8, ImmutAnyOrigin],
    Pointer[UInt8, ImmutAnyOrigin],
    c_size_t,
    c_int,
    Float64,
    Float64,
    Float64,
    c_int,
    Pointer[Int8, ImmutAnyOrigin],
    Int,
    Float64,
    Pointer[Int8, ImmutAnyOrigin],
    Pointer[Int8, ImmutAnyOrigin],
    Pointer[Int8, ImmutAnyOrigin],
) thin abi("C") -> Int


def _load_library() raises HTTPError -> OwnedDLHandle:
    comptime name = (
        "libreq_curl.dylib" if CompilationTarget.is_macos() else "libreq_curl.so"
    )
    # The bridge registers a libcurl atexit callback; keep its code mapped.
    comptime flags = RTLD.NOW | RTLD.LOCAL | RTLD.NODELETE
    var override = getenv("REQ_NATIVE_LIB")
    if override:
        try:
            return OwnedDLHandle(override, flags)
        except error:
            raise HTTPError(
                ErrorKind.ConnectError,
                "Cannot load REQ_NATIVE_LIB: " + override,
            )
    var prefix = getenv("CONDA_PREFIX")
    var paths = List[String]()
    if prefix:
        paths.append(prefix + "/lib/" + name)
    paths.append("build/" + name)
    paths.append("./" + name)
    for path in paths:
        try:
            return OwnedDLHandle(path, flags)
        except error:
            pass
    raise HTTPError(
        ErrorKind.ConnectError,
        (
            "Cannot load Req native transport; reinstall req or run make native"
            " for a source checkout"
        ),
    )


def _symbol[
    T: TrivialRegisterPassable
](library: OwnedDLHandle, name: String) raises HTTPError -> T:
    var symbol = library.get_symbol[T](name)
    if not symbol:
        raise HTTPError(
            ErrorKind.ConnectError, "Missing Req native symbol: " + name
        )
    var address = Int(symbol.value())
    return Pointer(to=address).unsafe_bitcast[T]()[]


struct NativePool(Movable):
    var library: OwnedDLHandle
    var handle: Int
    var close: def(Int) thin abi("C") -> NoneType
    var release: def(Int) thin abi("C") -> NoneType
    var transfer_headers: def(Int) thin abi("C") -> c_int
    var header_data: def(Int) thin abi("C") -> Int
    var header_size: def(Int) thin abi("C") -> Int
    var read: def(Int, Int, Int) thin abi("C") -> Int
    var read_raw: def(Int, Int, Int) thin abi("C") -> Int
    var free: def(Int) thin abi("C") -> NoneType
    var transfer_new: _TransferNew

    def __init__(
        out self,
        limits: Limits = Limits(),
        *,
        http1: Bool = True,
        http2: Bool = False,
    ) raises HTTPError:
        limits.validate()
        if not http1 and not http2:
            raise HTTPError(
                ErrorKind.InvalidRequest,
                "At least one HTTP protocol must be enabled",
            )
        self.library = _load_library()
        if http2:
            var supported = _symbol[def() thin abi("C") -> c_int](
                self.library, "req_http2_supported"
            )
            var capability = supported()
            if not capability:
                raise HTTPError(
                    ErrorKind.InvalidRequest,
                    "HTTP/2 requires libcurl built with HTTP/2 support",
                )
            if not http1 and capability < 2:
                raise HTTPError(
                    ErrorKind.InvalidRequest,
                    "HTTP/2-only mode requires libcurl 8.10 or later",
                )
        self.close = _symbol[type_of(self.close)](
            self.library, "req_pool_close"
        )
        self.release = _symbol[type_of(self.release)](
            self.library, "req_pool_release"
        )
        self.transfer_headers = _symbol[type_of(self.transfer_headers)](
            self.library, "req_transfer_headers"
        )
        self.header_data = _symbol[type_of(self.header_data)](
            self.library, "req_transfer_header_data"
        )
        self.header_size = _symbol[type_of(self.header_size)](
            self.library, "req_transfer_header_size"
        )
        self.read = _symbol[type_of(self.read)](
            self.library, "req_transfer_read"
        )
        self.read_raw = _symbol[type_of(self.read_raw)](
            self.library, "req_transfer_read_raw"
        )
        self.free = _symbol[type_of(self.free)](
            self.library, "req_transfer_free"
        )
        self.transfer_new = _symbol[_TransferNew](
            self.library, "req_transfer_new"
        )
        var create = _symbol[
            def(Int, Int, Float64, c_int, c_int) thin abi("C") -> Int
        ](self.library, "req_pool_new")
        self.handle = create(
            limits.max_connections.value() if limits.max_connections else 0,
            limits.max_keepalive_connections,
            limits.keepalive_expiry.value() if limits.keepalive_expiry else -1.0,
            c_int(http1),
            c_int(http2),
        )
        if not self.handle:
            raise HTTPError(
                ErrorKind.ConnectError, "Cannot initialize HTTP transport"
            )

    def __deinit__(deinit self):
        self.release(self.handle)


comptime Pool = Optional[ArcPointer[NativePool]]
