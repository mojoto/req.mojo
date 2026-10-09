"""HTTP request, response, and header models."""

from ._utils import MultiItems
from ._types import StringPairs
from ._exceptions import HTTPError, ErrorKind
from std.collections import Dict
from ._urls import URL
from ._types import Bytes
from ._json import JSONValue
from ._utils import is_token, decode_utf8

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

    def __init__(out self, method: String, url: String, *, headers: Headers = Headers(), content: Optional[Bytes] = None) raises HTTPError:
        var upper = method.upper()
        self.method = upper if upper in ["GET", "HEAD", "POST", "PUT", "PATCH", "DELETE", "OPTIONS"] else method
        self.url = URL(url)
        self.headers = headers
        self.content = None
        if content:
            self.content = content.value().copy()
        self.validate()

    def __init__(out self, *, copy: Self):
        self.method = copy.method
        self.url = copy.url
        self.headers = copy.headers
        self.content = None
        if copy.content:
            self.content = copy.content.value().copy()

    def validate(self) raises HTTPError:
        if not is_token(self.method):
            raise HTTPError(ErrorKind.InvalidRequest, "Invalid HTTP method")
        if self.method.upper() == "HEAD" and self.content:
            raise HTTPError(ErrorKind.InvalidRequest, "HEAD requests cannot have a body")
        if "Transfer-Encoding" in self.headers:
            raise HTTPError(ErrorKind.InvalidRequest, "Manual Transfer-Encoding is unsupported")
        var lengths = self.headers.get_all("Content-Length")
        if len(lengths) > 1:
            raise HTTPError(ErrorKind.InvalidRequest, "Duplicate Content-Length headers")
        if len(lengths) == 1:
            var expected = len(self.content.value()) if self.content else 0
            var digits = String(expected)
            if lengths[0] != digits:
                raise HTTPError(ErrorKind.InvalidRequest, "Content-Length does not match the body length")


struct Response(Movable):
    var status_code: Int
    var reason_phrase: String
    var http_version: String
    var url: URL
    var headers: Headers
    var request: Request
    var _content: Bytes

    def __init__(out self, status_code: Int, *, request: Request, headers: Headers = Headers(), content: Bytes = Bytes(), reason_phrase: String = "", http_version: String = "HTTP/1.1") raises HTTPError:
        if status_code < 100 or status_code > 599:
            raise HTTPError(ErrorKind.ProtocolError, "Invalid HTTP status code")
        self.status_code = status_code
        self.reason_phrase = reason_phrase
        self.http_version = http_version
        self.url = request.url
        self.headers = headers
        self.request = request
        self._content = content.copy() if request.method != "HEAD" else Bytes()

    def content(self) raises HTTPError -> Bytes:
        return self._content.copy()

    def read(mut self) raises HTTPError -> Bytes:
        return self._content.copy()

    def text(self, *, encoding: Optional[String] = None) raises HTTPError -> String:
        var codec = String("utf-8")
        if encoding:
            codec = encoding.value().lower()
        else:
            var content_type = self.headers.get("Content-Type")
            if content_type:
                for field in content_type.value().split(";"):
                    var item = String(field).strip()
                    var parts = item.split("=", maxsplit=1)
                    if len(parts) == 2 and String(parts[0]).strip().lower() == "charset":
                        codec = String(parts[1]).strip().strip('"').lower()
        if codec == "utf-8" or codec == "utf8":
            return decode_utf8(self._content)
        if codec in ["ascii", "us-ascii"]:
            for byte in self._content:
                if byte > 127:
                    raise HTTPError(ErrorKind.DecodeError, "Invalid ASCII bytes")
            return decode_utf8(self._content)
        if codec in ["iso-8859-1", "latin-1", "latin1"]:
            var result = String()
            for byte in self._content:
                result += String(chr(Int(byte)))
            return result^
        raise HTTPError(ErrorKind.DecodeError, "Unsupported response character encoding")

    def json(self) raises HTTPError -> JSONValue:
        return JSONValue.parse(decode_utf8(self._content))

    def is_success(self) -> Bool:
        return 200 <= self.status_code < 300

    def is_redirect(self) -> Bool:
        return self.status_code in [301, 302, 303, 307, 308] and "Location" in self.headers

    def raise_for_status(self) raises HTTPError:
        if 400 <= self.status_code < 600:
            raise HTTPError(ErrorKind.HTTPStatusError, "HTTP error status", method=self.request.method, url=String(self.url), status_code=self.status_code)

    def close(mut self):
        pass

    def is_closed(self) -> Bool:
        return True
