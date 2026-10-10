"""HTTP request, response, and header models."""

from ._utils import MultiItems
from ._types import StringPairs
from ._exceptions import HTTPError, ErrorKind
from std.collections import Dict
from ._urls import URL
from ._types import Bytes
from ._json import JSONValue
from ._utils import is_token, decode_utf8
from ._transports.default import CurlStream
from std.memory import Pointer
from std.origin import Origin


struct Headers(ImplicitlyCopyable, Sized):
    var _items: MultiItems[True]

    def __init__(out self):
        self._items = MultiItems[True]()

    def __init__(out self, pairs: StringPairs) raises HTTPError:
        self._items = MultiItems[True]()
        for pair in pairs:
            self._items.add(pair[0], pair[1])

    def __init__(out self, pairs: Dict[String, String]) raises HTTPError:
        self._items = MultiItems[True]()
        for entry in pairs.items():
            self._items.add(entry.key, entry.value)

    def get(self, name: String) -> Optional[String]:
        return self._items.get(name)

    def get_all(self, name: String) -> List[String]:
        return self._items.get_all(name)

    def __contains__(self, name: String) -> Bool:
        return name in self._items

    def __getitem__(self, name: String) raises HTTPError -> String:
        return self._items[name]

    def __len__(self) -> Int:
        return len(self._items)

    def items(self) -> StringPairs:
        return self._items.items()

    def add(mut self, name: String, value: String) raises HTTPError:
        self._items.add(name, value)

    def set(mut self, name: String, value: String) raises HTTPError:
        self._items.set(name, value)

    def remove(mut self, name: String):
        self._items.remove(name)

    def merge(mut self, other: Self) raises HTTPError:
        self._items.merge(other._items)


struct Request(ImplicitlyCopyable):
    var method: String
    var url: URL
    var headers: Headers
    var content: Optional[Bytes]
    var _cookie_from_jar: Optional[String]

    def __init__(
        out self,
        method: String,
        url: String,
        *,
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
    ) raises HTTPError:
        var target = URL(url)
        var body: Optional[Bytes] = None
        if content:
            body = content.value().copy()
        self = Self(method, _url=target^, _headers=headers, _content=body^)

    def __init__(
        out self,
        method: String,
        *,
        var _url: URL,
        var _headers: Headers,
        var _content: Optional[Bytes],
    ) raises HTTPError:
        var upper = method.upper()
        self.method = (
            upper if upper
            in [
                "GET",
                "HEAD",
                "POST",
                "PUT",
                "PATCH",
                "DELETE",
                "OPTIONS",
            ] else method
        )
        self.url = _url^
        self.headers = _headers^
        self.content = _content^
        self._cookie_from_jar = None
        self.validate()

    def __init__(out self, *, copy: Self):
        self.method = copy.method
        self.url = copy.url
        self.headers = copy.headers
        self.content = None
        self._cookie_from_jar = copy._cookie_from_jar
        if copy.content:
            self.content = copy.content.value().copy()

    def validate(self) raises HTTPError:
        if not is_token(self.method):
            raise HTTPError(ErrorKind.InvalidRequest, "Invalid HTTP method")
        if self.method.upper() == "HEAD" and self.content:
            raise HTTPError(
                ErrorKind.InvalidRequest, "HEAD requests cannot have a body"
            )
        if "Transfer-Encoding" in self.headers:
            raise HTTPError(
                ErrorKind.InvalidRequest,
                "Manual Transfer-Encoding is unsupported",
            )
        var lengths = self.headers.get_all("Content-Length")
        if len(lengths) > 1:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Duplicate Content-Length headers"
            )
        if len(lengths) == 1:
            var expected = len(self.content.value()) if self.content else 0
            var digits = String(expected)
            if lengths[0] != digits:
                raise HTTPError(
                    ErrorKind.InvalidRequest,
                    "Content-Length does not match the body length",
                )


struct Response(Movable):
    var status_code: Int
    var reason_phrase: String
    var http_version: String
    var url: URL
    var headers: Headers
    var request: Request
    var _content: Bytes
    var _stream: Optional[CurlStream]
    var _cached: Bool
    var _consumed: Bool
    var _eof: Bool
    var _offset: Int

    def __init__(
        out self,
        status_code: Int,
        *,
        request: Request,
        headers: Headers = Headers(),
        content: Bytes = Bytes(),
        reason_phrase: String = "",
        http_version: String = "HTTP/1.1",
    ) raises HTTPError:
        if status_code < 100 or status_code > 599:
            raise HTTPError(ErrorKind.ProtocolError, "Invalid HTTP status code")
        self.status_code = status_code
        self.reason_phrase = reason_phrase
        self.http_version = http_version
        self.url = request.url
        self.headers = headers
        self.request = request
        self._content = content.copy() if request.method != "HEAD" else Bytes()
        self._stream = None
        self._cached = True
        self._consumed = False
        self._eof = False
        self._offset = 0

    @staticmethod
    def from_stream(
        var source: CurlStream, request: Request
    ) raises HTTPError -> Self:
        var lines = source.headers().split("\r\n")
        var status = String(lines[0]).split(" ", maxsplit=2)
        if len(status) < 2:
            raise HTTPError(
                ErrorKind.ProtocolError, "Missing response status line"
            )
        var code: Int
        try:
            code = Int(status[1])
        except:
            raise HTTPError(
                ErrorKind.ProtocolError, "Invalid response status line"
            )
        var headers = Headers()
        for i in range(1, len(lines)):
            if not lines[i]:
                break
            var pair = String(lines[i]).split(":", maxsplit=1)
            if len(pair) != 2:
                raise HTTPError(
                    ErrorKind.ProtocolError, "Invalid response header"
                )
            headers.add(String(pair[0]), String(String(pair[1]).strip()))
        for value in headers.get_all("Content-Encoding"):
            for encoding in value.split(","):
                if String(encoding).strip().lower() not in [
                    "identity",
                    "gzip",
                    "deflate",
                ]:
                    raise HTTPError(
                        ErrorKind.DecodeError,
                        "Unsupported response content encoding",
                    )
        var response = Self(
            code,
            request=request,
            headers=headers,
            reason_phrase=String(status[2]) if len(status) == 3 else String(),
            http_version=String(status[0]),
        )
        response._stream = source^
        response._cached = False
        return response^

    def _require_content(self) raises HTTPError:
        if self._cached:
            return
        if self._consumed:
            raise HTTPError(
                ErrorKind.StreamConsumed, "Response has been partially consumed"
            )
        if self.is_closed():
            raise HTTPError(ErrorKind.StreamClosed, "Response stream is closed")
        raise HTTPError(
            ErrorKind.StreamNotRead,
            "Read the response before accessing its content",
        )

    def _read_stream_chunk(
        mut self, size: Int
    ) raises HTTPError -> Optional[Bytes]:
        try:
            return self._stream.value().read_chunk(size)
        except error:
            error.method = self.request.method
            error.url = String(self.url)
            raise error

    def content(self) raises HTTPError -> Bytes:
        self._require_content()
        return self._content.copy()

    def _read_content(mut self) raises HTTPError:
        if not self._cached:
            if self._consumed or self.is_closed():
                self._require_content()
            var buffer = Bytes(length=16384, fill=0)
            try:
                while True:
                    var count = self._stream.value()._read_into(buffer)
                    if count == 0:
                        break
                    self._content.extend(Span(buffer)[:count])
            except error:
                error.method = self.request.method
                error.url = String(self.url)
                raise error
            self._cached = True
            self._eof = True

    def read(mut self) raises HTTPError -> Bytes:
        self._read_content()
        return self._content.copy()

    def read_chunk(
        mut self, max_bytes: Int = 65536
    ) raises HTTPError -> Optional[Bytes]:
        if max_bytes <= 0:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Chunk size must be positive"
            )
        if self._cached:
            if self._offset >= len(self._content):
                return None
            var bytes = Bytes()
            var end = self._offset + min(
                max_bytes, len(self._content) - self._offset
            )
            bytes.extend(Span(self._content)[self._offset : end])
            self._offset = end
            return bytes^
        if self._eof:
            return None
        if self.is_closed():
            raise HTTPError(ErrorKind.StreamClosed, "Response stream is closed")
        self._consumed = True
        var result = self._read_stream_chunk(max_bytes)
        if not result:
            self._eof = True
        return result^

    def text(
        self, *, encoding: Optional[String] = None
    ) raises HTTPError -> String:
        self._require_content()
        var codec = String("utf-8")
        if encoding:
            codec = encoding.value().lower()
        else:
            var content_type = self.headers.get("Content-Type")
            if content_type:
                for field in content_type.value().split(";"):
                    var item = String(field).strip()
                    var parts = item.split("=", maxsplit=1)
                    if (
                        len(parts) == 2
                        and String(parts[0]).strip().lower() == "charset"
                    ):
                        codec = String(parts[1]).strip().strip('"').lower()
        if codec == "utf-8" or codec == "utf8":
            return decode_utf8(self._content)
        if codec in ["ascii", "us-ascii"]:
            for byte in self._content:
                if byte > 127:
                    raise HTTPError(
                        ErrorKind.DecodeError, "Invalid ASCII bytes"
                    )
            return decode_utf8(self._content)
        if codec in ["iso-8859-1", "latin-1", "latin1"]:
            var result = String()
            for byte in self._content:
                result += String(chr(Int(byte)))
            return result^
        raise HTTPError(
            ErrorKind.DecodeError, "Unsupported response character encoding"
        )

    def json(self) raises HTTPError -> JSONValue:
        self._require_content()
        return JSONValue.parse(decode_utf8(self._content))

    def is_success(self) -> Bool:
        return 200 <= self.status_code < 300

    def is_redirect(self) -> Bool:
        return (
            self.status_code in [301, 302, 303, 307, 308]
            and "Location" in self.headers
        )

    def raise_for_status(self) raises HTTPError:
        if 400 <= self.status_code < 600:
            raise HTTPError(
                ErrorKind.HTTPStatusError,
                "HTTP error status",
                method=self.request.method,
                url=String(self.url),
                status_code=self.status_code,
            )

    def close(mut self):
        if self._stream:
            self._stream.value().close()

    def is_closed(self) -> Bool:
        return not self._stream or not self._stream.value().handle

    def __enter__(
        mut self,
    ) raises HTTPError -> ResponseContext[origin_of(self)]:
        if not self._cached and self.is_closed():
            raise HTTPError(ErrorKind.StreamClosed, "Response stream is closed")
        return ResponseContext[origin_of(self)](
            Pointer(to=self),
            self.status_code,
            self.reason_phrase,
            self.http_version,
            self.headers,
            self.url,
            self.request,
        )

    def __exit__(mut self):
        self.close()


@fieldwise_init
struct ResponseContext[origin: Origin[mut=True]](Movable):
    """A borrowed context view; it cannot outlive its owning response."""

    var _response: Pointer[Response, Self.origin]
    var status_code: Int
    var reason_phrase: String
    var http_version: String
    var headers: Headers
    var url: URL
    var request: Request

    def content(self) raises HTTPError -> Bytes:
        return self._response[].content()

    def read(mut self) raises HTTPError -> Bytes:
        return self._response[].read()

    def read_chunk(
        mut self, max_bytes: Int = 65536
    ) raises HTTPError -> Optional[Bytes]:
        return self._response[].read_chunk(max_bytes)

    def text(
        self, *, encoding: Optional[String] = None
    ) raises HTTPError -> String:
        return self._response[].text(encoding=encoding)

    def json(self) raises HTTPError -> JSONValue:
        return self._response[].json()

    def raise_for_status(self) raises HTTPError:
        self._response[].raise_for_status()

    def is_success(self) -> Bool:
        return self._response[].is_success()

    def is_redirect(self) -> Bool:
        return self._response[].is_redirect()

    def is_closed(self) -> Bool:
        return self._response[].is_closed()

    def close(mut self):
        self._response[].close()
