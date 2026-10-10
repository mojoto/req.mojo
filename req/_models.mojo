"""HTTP request, response, and header models."""

from ._headers import Headers
from ._cookies import CookieJar
from ._exceptions import HTTPError, ErrorKind
from std.time import perf_counter_ns
from ._urls import URL
from ._types import Bytes
from ._body import RequestBody
from ._json import JSONValue
from ._utils import is_token, decode_utf8
from ._transports.default import CurlStream
from ._streams import ByteStream
from std.memory import Pointer, ArcPointer
from std.origin import Origin


struct Request(ImplicitlyCopyable):
    var method: String
    var url: URL
    var headers: Headers
    var content: Optional[Bytes]
    var body: Optional[RequestBody]
    var _cookie_from_jar: Optional[String]

    def __init__(
        out self,
        method: String,
        url: String,
        *,
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
    ) raises HTTPError:
        var target = URL(url)
        var raw_body: Optional[Bytes] = None
        if content:
            raw_body = content.value().copy()
        self = Self(
            method,
            _url=target^,
            _headers=headers,
            _content=raw_body^,
            _body=body,
        )

    def __init__(
        out self,
        method: String,
        *,
        var _url: URL,
        var _headers: Headers,
        var _content: Optional[Bytes],
        _body: Optional[RequestBody] = None,
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
        self.body = _body
        self._cookie_from_jar = None
        self.validate()

    def __init__(out self, *, copy: Self):
        self.method = copy.method
        self.url = copy.url
        self.headers = copy.headers
        self.content = None
        self.body = copy.body
        self._cookie_from_jar = copy._cookie_from_jar
        if copy.content:
            self.content = copy.content.value().copy()

    def validate(self) raises HTTPError:
        if not is_token(self.method):
            raise HTTPError(ErrorKind.InvalidRequest, "Invalid HTTP method")
        if self.content and self.body:
            raise HTTPError(
                ErrorKind.InvalidRequest,
                "content and body are mutually exclusive",
            )
        if self.body:
            _ = self.body.value()._handle()
        if self.method.upper() == "HEAD" and (self.content or self.body):
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
            if self.body:
                var size = self.body.value().content_length()
                if not size:
                    raise HTTPError(
                        ErrorKind.InvalidRequest,
                        "Content-Length requires a known body length",
                    )
                expected = size.value()
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
    var history: ResponseHistory
    var next_request: Optional[Request]
    var cookies: CookieJar
    var _started_at: Optional[Int]
    var _elapsed_seconds: Optional[Float64]
    var _content: Bytes
    var _stream: Optional[ByteStream]
    var _cached: Bool
    var _consumed: Bool
    var _eof: Bool
    var _offset: Int
    var _raw_mode: Bool

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
        self.history = ResponseHistory()
        self.next_request = None
        self.cookies = CookieJar()
        self.cookies.extract(headers, request.url)
        self._started_at = None
        self._elapsed_seconds = None
        self._content = content.copy() if request.method != "HEAD" else Bytes()
        self._stream = None
        self._cached = True
        self._consumed = False
        self._eof = False
        self._offset = 0
        self._raw_mode = False

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
        var response = Self(
            code,
            request=request,
            headers=headers,
            reason_phrase=String(status[2]) if len(status) == 3 else String(),
            http_version=String(status[0]),
        )
        response._stream = ByteStream(source^)
        response._cached = False
        return response^

    @staticmethod
    def from_byte_stream(
        var source: ByteStream,
        request: Request,
        *,
        status_code: Int = 200,
        headers: Headers = Headers(),
        http_version: String = "HTTP/1.1",
    ) raises HTTPError -> Self:
        var response = Self(
            status_code,
            request=request,
            headers=headers,
            http_version=http_version,
        )
        if request.method == "HEAD":
            source.close()
            return response^
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
            var result = self._stream.value().read_chunk(size)
            if not result:
                self.close()
            return result^
        except error:
            self.close()
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
            try:
                while True:
                    var chunk = self._stream.value().read_chunk(16384)
                    if not chunk:
                        break
                    self._content.extend(Span(chunk.value()))
            except error:
                self.close()
                error.method = self.request.method
                error.url = String(self.url)
                raise error
            self._cached = True
            self._eof = True
            self.close()

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
        if self._raw_mode:
            raise HTTPError(
                ErrorKind.StreamConsumed,
                "Raw response stream has been consumed",
            )
        if self._eof:
            return None
        if self.is_closed():
            raise HTTPError(ErrorKind.StreamClosed, "Response stream is closed")
        self._consumed = True
        var result = self._read_stream_chunk(max_bytes)
        if not result:
            self._eof = True
        return result^

    def _text_encoding(self, encoding: Optional[String]) -> String:
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
        return codec^

    def text(
        self, *, encoding: Optional[String] = None
    ) raises HTTPError -> String:
        self._require_content()
        return _decode_text(self._content, self._text_encoding(encoding))

    def iter_bytes(
        mut self, chunk_size: Int = 65536
    ) raises HTTPError -> _ByteIterator[origin_of(self)]:
        return _ByteIterator[origin_of(self)](Pointer(to=self), chunk_size)

    def iter_raw(
        mut self, chunk_size: Int = 65536
    ) raises HTTPError -> _ByteIterator[origin_of(self)]:
        return _ByteIterator[origin_of(self)](
            Pointer(to=self), chunk_size, raw=True
        )

    def iter_text(
        mut self, chunk_size: Int = 65536, *, encoding: Optional[String] = None
    ) raises HTTPError -> _TextIterator[origin_of(self)]:
        var codec = self._text_encoding(encoding)
        return _TextIterator[origin_of(self)](
            self.iter_bytes(), chunk_size, codec
        )

    def iter_lines(
        mut self, *, encoding: Optional[String] = None
    ) raises HTTPError -> _LineIterator[origin_of(self)]:
        return _LineIterator[origin_of(self)](
            self.iter_text(4096, encoding=encoding)
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

    def _start_timing(mut self, started_at: Int):
        self._started_at = started_at
        self._elapsed_seconds = None
        if self.is_closed():
            self._finish_timing()

    def _finish_timing(mut self):
        if self._started_at and not self._elapsed_seconds:
            self._elapsed_seconds = (
                Float64(perf_counter_ns() - self._started_at.value())
                / 1_000_000_000.0
            )

    def elapsed(self) raises HTTPError -> Float64:
        """Return seconds from sending the request through closing its response.
        """
        if not self._elapsed_seconds:
            raise HTTPError(
                ErrorKind.StreamNotRead,
                (
                    "Response elapsed time is available after reading or"
                    " closing the response"
                ),
            )
        return self._elapsed_seconds.value()

    def close(mut self):
        if self._stream:
            self._stream.value().close()
        self._finish_timing()

    def is_closed(self) -> Bool:
        return not self._stream or self._stream.value().is_closed()

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
            self.history,
            self.next_request,
            self.cookies,
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
    var history: ResponseHistory
    var next_request: Optional[Request]
    var cookies: CookieJar

    def elapsed(self) raises HTTPError -> Float64:
        return self._response[].elapsed()

    def content(self) raises HTTPError -> Bytes:
        return self._response[].content()

    def read(mut self) raises HTTPError -> Bytes:
        return self._response[].read()

    def read_chunk(
        mut self, max_bytes: Int = 65536
    ) raises HTTPError -> Optional[Bytes]:
        return self._response[].read_chunk(max_bytes)

    def iter_bytes(
        mut self, chunk_size: Int = 65536
    ) raises HTTPError -> _ByteIterator[Self.origin]:
        return _ByteIterator[Self.origin](self._response, chunk_size)

    def iter_raw(
        mut self, chunk_size: Int = 65536
    ) raises HTTPError -> _ByteIterator[Self.origin]:
        return _ByteIterator[Self.origin](self._response, chunk_size, raw=True)

    def iter_text(
        mut self, chunk_size: Int = 65536, *, encoding: Optional[String] = None
    ) raises HTTPError -> _TextIterator[Self.origin]:
        return _TextIterator[Self.origin](
            self.iter_bytes(),
            chunk_size,
            self._response[]._text_encoding(encoding),
        )

    def iter_lines(
        mut self, *, encoding: Optional[String] = None
    ) raises HTTPError -> _LineIterator[Self.origin]:
        return _LineIterator[Self.origin](
            self.iter_text(4096, encoding=encoding)
        )

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


def _decode_text(data: Bytes, codec: String) raises HTTPError -> String:
    if codec == "utf-8" or codec == "utf8":
        return decode_utf8(data)
    if codec in ["ascii", "us-ascii"]:
        for byte in data:
            if byte > 127:
                raise HTTPError(ErrorKind.DecodeError, "Invalid ASCII bytes")
        return decode_utf8(data)
    if codec in ["iso-8859-1", "latin-1", "latin1"]:
        var result = String()
        for byte in data:
            result += String(chr(Int(byte)))
        return result^
    raise HTTPError(
        ErrorKind.DecodeError, "Unsupported response character encoding"
    )


struct _ByteIterator[o: Origin[mut=True]](Movable):
    var _response: Pointer[Response, Self.o]
    var _size: Int
    var _raw: Bool
    var _started: Bool
    var _done: Bool
    var _offset: Int
    var _ready: Optional[Bytes]

    def __init__(
        out self,
        response: Pointer[Response, Self.o],
        size: Int,
        *,
        raw: Bool = False,
    ) raises HTTPError:
        if size <= 0:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Chunk size must be positive"
            )
        self._response = response
        self._size = size
        self._raw = raw
        self._started = False
        self._done = False
        self._offset = 0
        self._ready = None

    def __iter__(var self) -> Self:
        return self^

    def __has_next__(mut self) raises HTTPError -> Bool:
        if not self._ready:
            self._ready = self._read_next()
        return Bool(self._ready)

    def __next__(mut self) -> Bytes:
        return self._ready.take()

    def next_chunk(mut self) raises HTTPError -> Optional[Bytes]:
        if self._ready:
            return self._ready.take()
        return self._read_next()

    def _read_next(mut self) raises HTTPError -> Optional[Bytes]:
        if self._done:
            return None
        if not self._started:
            if self._response[]._consumed or (
                self._raw and self._response[]._cached
            ):
                raise HTTPError(
                    ErrorKind.StreamConsumed,
                    "Response stream has already been consumed",
                )
            if not self._response[]._cached:
                if self._response[].is_closed():
                    raise HTTPError(
                        ErrorKind.StreamClosed, "Response stream is closed"
                    )
                self._response[]._consumed = True
                self._response[]._raw_mode = self._raw
            self._started = True
        var result = Bytes(capacity=self._size)
        if self._response[]._cached:
            var end = min(
                self._offset + self._size, len(self._response[]._content)
            )
            result.extend(Span(self._response[]._content)[self._offset : end])
            self._offset = end
            self._done = end == len(self._response[]._content)
        else:
            try:
                while len(result) < self._size:
                    var chunk = (
                        self._response[]
                        ._stream.value()
                        .read_chunk(self._size - len(result), raw=self._raw)
                    )
                    if not chunk:
                        self._response[]._eof = True
                        self._response[].close()
                        self._done = True
                        break
                    result.extend(Span(chunk.value()))
            except error:
                self._response[].close()
                error.method = self._response[].request.method
                error.url = String(self._response[].url)
                raise error
        if not result:
            return None
        return result^


def _utf8_prefix(data: Bytes, final: Bool) raises HTTPError -> Int:
    var offset = 0
    while offset < len(data):
        var lead = Int(data[offset])
        var width = 1 if lead < 128 else (
            2 if 194
            <= lead
            <= 223 else (
                3 if 224 <= lead <= 239 else (4 if 240 <= lead <= 244 else 0)
            )
        )
        if width == 0 or (final and offset + width > len(data)):
            raise HTTPError(ErrorKind.DecodeError, "Invalid UTF-8 bytes")
        if offset + width > len(data):
            break
        offset += width
    return offset


struct _TextIterator[o: Origin[mut=True]](Movable):
    var _bytes: _ByteIterator[Self.o]
    var _size: Int
    var _codec: String
    var _pending: Bytes
    var _text: String
    var _done: Bool
    var _ready: Optional[String]

    def __init__(
        out self, var bytes: _ByteIterator[Self.o], size: Int, codec: String
    ) raises HTTPError:
        if size <= 0:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Chunk size must be positive"
            )
        if codec not in [
            "utf-8",
            "utf8",
            "ascii",
            "us-ascii",
            "iso-8859-1",
            "latin-1",
            "latin1",
        ]:
            raise HTTPError(
                ErrorKind.DecodeError, "Unsupported text encoding: " + codec
            )
        self._bytes = bytes^
        self._size = size
        self._codec = codec
        self._pending = Bytes()
        self._text = String()
        self._done = False
        self._ready = None

    def __iter__(var self) -> Self:
        return self^

    def __has_next__(mut self) raises HTTPError -> Bool:
        if not self._ready:
            self._ready = self.next_chunk()
        return Bool(self._ready)

    def __next__(mut self) -> String:
        return self._ready.take()

    def next_chunk(mut self) raises HTTPError -> Optional[String]:
        if self._ready:
            return self._ready.take()
        try:
            while not self._done and len(self._text.codepoints()) < self._size:
                var chunk = self._bytes.next_chunk()
                self._done = not Bool(chunk)
                if chunk:
                    self._pending.extend(Span(chunk.value()))
                var end = _utf8_prefix(
                    self._pending, self._done
                ) if self._codec in ["utf-8", "utf8"] else len(self._pending)
                var complete = Bytes()
                complete.extend(Span(self._pending)[:end])
                self._text += _decode_text(complete, self._codec)
                var remainder = Bytes()
                remainder.extend(Span(self._pending)[end:])
                self._pending = remainder^
            if not self._text:
                return None
            var result = String()
            var count = 0
            for character in self._text.codepoints():
                if count == self._size:
                    break
                result += String(character)
                count += 1
            var remaining = Bytes()
            remaining.extend(self._text.as_bytes()[result.byte_length() :])
            var remainder = decode_utf8(remaining)
            self._text = remainder^
            return result^
        except error:
            self._bytes._response[].close()
            error.method = self._bytes._response[].request.method
            error.url = String(self._bytes._response[].url)
            raise error


struct _LineIterator[o: Origin[mut=True]](Movable):
    var _text: _TextIterator[Self.o]
    var _lines: List[String]
    var _index: Int
    var _line: String
    var _skip_lf: Bool
    var _done: Bool
    var _ready: Optional[String]

    def __init__(out self, var text: _TextIterator[Self.o]):
        self._text = text^
        self._lines = List[String]()
        self._index = 0
        self._line = String()
        self._skip_lf = False
        self._done = False
        self._ready = None

    def __iter__(var self) -> Self:
        return self^

    def __has_next__(mut self) raises HTTPError -> Bool:
        if not self._ready:
            self._ready = self.next_chunk()
        return Bool(self._ready)

    def __next__(mut self) -> String:
        return self._ready.take()

    def next_chunk(mut self) raises HTTPError -> Optional[String]:
        if self._ready:
            return self._ready.take()
        while self._index == len(self._lines) and not self._done:
            self._lines.clear()
            self._index = 0
            var chunk = self._text.next_chunk()
            if not chunk:
                self._done = True
                if self._line:
                    self._lines.append(self._line)
                    self._line = String()
                break
            for character in chunk.value().codepoints():
                var char = String(character)
                if self._skip_lf:
                    self._skip_lf = False
                    if char == "\n":
                        continue
                if char in [
                    "\r",
                    "\n",
                    "\v",
                    "\f",
                    "\x1c",
                    "\x1d",
                    "\x1e",
                    "\u0085",
                    "\u2028",
                    "\u2029",
                ]:
                    self._lines.append(self._line)
                    self._line = String()
                    self._skip_lf = char == "\r"
                else:
                    self._line += char
        if self._index == len(self._lines):
            return None
        var result = self._lines[self._index]
        self._index += 1
        return result^


struct ResponseHistory(ImplicitlyCopyable, Sized):
    var _items: List[ArcPointer[Response]]

    def __init__(out self):
        self._items = List[ArcPointer[Response]]()

    def __init__(out self, *, copy: Self):
        self._items = copy._items.copy()

    def __len__(self) -> Int:
        return len(self._items)

    def __getitem__(
        self, index: Int
    ) raises HTTPError -> ref[origin_of(self._items)] Response:
        var offset = index if index >= 0 else len(self._items) + index
        if offset < 0 or offset >= len(self._items):
            raise HTTPError(
                ErrorKind.InvalidRequest,
                "Response history index is out of range",
            )
        # The bounds check and returned origin retain the immutable history entry.
        return self._items.unsafe_ptr()[unsafe_offset=offset][]

    def _append(mut self, var response: Response):
        self._items.append(ArcPointer(response^))

    def __iter__(self) -> _HistoryIterator[origin_of(self._items)]:
        return _HistoryIterator[origin_of(self._items)](
            self._items.unsafe_ptr(), len(self._items), 0
        )


@fieldwise_init
struct _HistoryIterator[o: Origin[mut=False]](Movable):
    var _items: Pointer[ArcPointer[Response], Self.o]
    var _length: Int
    var _index: Int

    def __iter__(var self) -> Self:
        return self^

    def __has_next__(self) -> Bool:
        return self._index < self._length

    def __next__(mut self) -> ref[Self.o] Response:
        self._index += 1
        return self._items[unsafe_offset=self._index - 1][]
