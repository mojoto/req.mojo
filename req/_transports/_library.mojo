"""Load the packaged native bridge and retain it for active requests."""

from std.ffi import OwnedDLHandle, RTLD, c_int
from std.memory import ArcPointer, Pointer
from std.os import getenv
from std.sys import CompilationTarget
from .._exceptions import HTTPError, ErrorKind


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
    var transfer_new: def(
        Int,
        Int,
        Int,
        Int,
        Int,
        Int,
        c_int,
        Float64,
        Float64,
        Float64,
        c_int,
        Int,
    ) thin abi("C") -> Int
    var transfer_headers: def(Int) thin abi("C") -> c_int
    var header_data: def(Int) thin abi("C") -> Int
    var header_size: def(Int) thin abi("C") -> Int
    var read: def(Int, Int, Int) thin abi("C") -> Int
    var free: def(Int) thin abi("C") -> NoneType

    def __init__(out self) raises HTTPError:
        self.library = _load_library()
        self.close = _symbol[type_of(self.close)](
            self.library, "req_pool_close"
        )
        self.release = _symbol[type_of(self.release)](
            self.library, "req_pool_release"
        )
        self.transfer_new = _symbol[type_of(self.transfer_new)](
            self.library, "req_transfer_new"
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
        self.free = _symbol[type_of(self.free)](
            self.library, "req_transfer_free"
        )
        var create = _symbol[def() thin abi("C") -> Int](
            self.library, "req_pool_new"
        )
        self.handle = create()
        if not self.handle:
            raise HTTPError(
                ErrorKind.ConnectError, "Cannot initialize HTTP transport"
            )

    def __deinit__(deinit self):
        self.release(self.handle)


comptime Pool = Optional[ArcPointer[NativePool]]
