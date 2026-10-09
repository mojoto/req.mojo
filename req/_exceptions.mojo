"""Structured errors shared by every public HTTP operation."""

from std.format import Writable, Writer


@fieldwise_init
struct ErrorKind(Equatable, TrivialRegisterPassable, Writable):
    var _code: Int

    comptime InvalidURL = Self(0)
    comptime InvalidRequest = Self(1)
    comptime ConnectError = Self(2)
    comptime ReadError = Self(3)
    comptime WriteError = Self(4)
    comptime TLSError = Self(5)
    comptime ProtocolError = Self(6)
    comptime ConnectTimeout = Self(7)
    comptime ReadTimeout = Self(8)
    comptime WriteTimeout = Self(9)
    comptime TooManyRedirects = Self(10)
    comptime UnsafeRedirect = Self(11)
    comptime HTTPStatusError = Self(12)
    comptime DecodeError = Self(13)
    comptime JSONDecodeError = Self(14)
    comptime ClientClosed = Self(15)
    comptime StreamClosed = Self(16)
    comptime StreamNotRead = Self(17)
    comptime StreamConsumed = Self(18)

    def __eq__(self, other: Self) -> Bool:
        return self._code == other._code

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    def write_to(self, mut writer: Some[Writer]):
        var names: List[String] = [
            "InvalidURL",
            "InvalidRequest",
            "ConnectError",
            "ReadError",
            "WriteError",
            "TLSError",
            "ProtocolError",
            "ConnectTimeout",
            "ReadTimeout",
            "WriteTimeout",
            "TooManyRedirects",
            "UnsafeRedirect",
            "HTTPStatusError",
            "DecodeError",
            "JSONDecodeError",
            "ClientClosed",
            "StreamClosed",
            "StreamNotRead",
            "StreamConsumed",
        ]
        if 0 <= self._code < len(names):
            writer.write(names[self._code])
        else:
            writer.write("HTTPError")


struct HTTPError(ImplicitlyCopyable, Writable):
    var kind: ErrorKind
    var message: String
    var method: Optional[String]
    var url: Optional[String]
    var status_code: Optional[Int]

    def __init__(
        out self,
        kind: ErrorKind,
        message: String,
        *,
        method: Optional[String] = None,
        url: Optional[String] = None,
        status_code: Optional[Int] = None,
    ):
        self.kind = kind
        self.message = message
        self.method = method
        self.url = url
        self.status_code = status_code

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.kind, ": ", self.message)
