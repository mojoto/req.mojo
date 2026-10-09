"""URLs and ordered, repeatable query parameters."""

from std.collections import Dict
from ._exceptions import HTTPError, ErrorKind
from ._utils import MultiItems, StringPairs, find_byte, percent_decode, percent_encode, hex_value
from std.format import Writable, Writer
from std.ffi import external_call, c_int
from std.sys import CompilationTarget


def _slice(text: String, start: Int, end: Int = -1) -> String:
    var stop = text.byte_length() if end < 0 else end
    return String(text[byte=start:stop])


def _url_component(text: String, *, query: Bool = False) raises HTTPError -> String:
    var result = String()
    var i = 0
    while i < text.byte_length():
        var c = Int(text.as_bytes()[i])
        if c < 32 or c == 127 or c == 92:
            raise HTTPError(ErrorKind.InvalidURL, "Invalid character in URL")
        if c == 37:
            if i + 2 >= text.byte_length() or hex_value(Int(text.as_bytes()[i + 1])) < 0 or hex_value(Int(text.as_bytes()[i + 2])) < 0:
                raise HTTPError(ErrorKind.InvalidURL, "Invalid percent escape in URL")
            result += String(text[byte=i:i + 3])
            i += 3
        elif c > 127 or c == 32 or c == 34 or c in [60, 62, 96, 123, 124, 125, 94]:
            var digits = String("0123456789ABCDEF")
            result += "%" + String(digits[byte=c // 16:c // 16 + 1]) + String(digits[byte=c % 16:c % 16 + 1])
            i += 1
        else:
            result += String(text[byte=i:i + 1])
            i += 1
    return result^


def _remove_dot_segments(path: String) -> String:
    var input = path
    var output = String()
    while input.byte_length() != 0:
        if input.startswith("../"):
            input = _slice(input, 3)
        elif input.startswith("./"):
            input = _slice(input, 2)
        elif input.startswith("/./"):
            input = _slice(input, 2)
        elif input == "/.":
            input = "/"
        elif input.startswith("/../") or input == "/..":
            input = _slice(input, 3) if input != "/.." else String("/")
            var last = 0
            for i in range(output.byte_length()):
                if output.as_bytes()[i] == 47:
                    last = i
            output = _slice(output, 0, last)
        elif input == "." or input == "..":
            input = ""
        else:
            var end = find_byte(input, 47, 1 if input.startswith("/") else 0)
            output += String(input[byte=0:end])
            input = _slice(input, end)
    return output^


struct URL(ImplicitlyCopyable, Writable, Equatable):
    var _scheme: String
    var _host: String
    var _port: Optional[Int]
    var _path: String
    var _query: String
    var _has_query: Bool
    var _authority: String

    def __init__(out self, text: String) raises HTTPError:
        var colon = find_byte(text, 58)
        if colon == text.byte_length():
            raise HTTPError(ErrorKind.InvalidURL, "An absolute HTTP or HTTPS URL is required")
        self._scheme = String(text[byte=0:colon]).lower()
        if self._scheme != "http" and self._scheme != "https":
            raise HTTPError(ErrorKind.InvalidURL, "Only HTTP and HTTPS URLs are supported")
        if not String(text[byte=colon + 1:]).startswith("//"):
            raise HTTPError(ErrorKind.InvalidURL, "URL is missing an authority")
        var start = colon + 3
        var end = text.byte_length()
        for i in range(start, end):
            if Int(text.as_bytes()[i]) in [47, 63, 35]:
                end = i
                break
        var authority = String(text[byte=start:end])
        if authority.byte_length() == 0 or find_byte(authority, 64) != authority.byte_length():
            raise HTTPError(ErrorKind.InvalidURL, "URL must have a host and cannot contain userinfo")
        self._port = None
        var port_start = authority.byte_length()
        if authority.startswith("["):
            var bracket = find_byte(authority, 93)
            if bracket == authority.byte_length():
                raise HTTPError(ErrorKind.InvalidURL, "Unclosed IPv6 address")
            self._host = String(authority[byte=1:bracket]).lower()
            var address = List[UInt8](length=16, fill=0)
            var valid = external_call["inet_pton", c_int](c_int(30 if CompilationTarget.is_macos() else 10), self._host.as_c_string_span().ptr(), address.unsafe_ptr())
            if valid != 1:
                raise HTTPError(ErrorKind.InvalidURL, "Invalid IPv6 address")
            if bracket + 1 < authority.byte_length():
                if authority.as_bytes()[bracket + 1] != 58:
                    raise HTTPError(ErrorKind.InvalidURL, "Invalid IPv6 authority")
                port_start = bracket + 2
            self._authority = "[" + self._host + "]"
        else:
            var separator = find_byte(authority, 58)
            self._host = String(authority[byte=0:separator]).lower()
            if self._host.byte_length() == 0:
                raise HTTPError(ErrorKind.InvalidURL, "URL host is empty")
            for byte in self._host.as_bytes():
                var c = Int(byte)
                if not (48 <= c <= 57 or 97 <= c <= 122 or c in [45, 46]):
                    raise HTTPError(ErrorKind.InvalidURL, "Host must be an ASCII hostname or IP address")
            if separator < authority.byte_length():
                port_start = separator + 1
            self._authority = self._host
        if port_start < authority.byte_length():
            var number = 0
            for byte in String(authority[byte=port_start:]).as_bytes():
                if not (48 <= Int(byte) <= 57) or number > 65535:
                    raise HTTPError(ErrorKind.InvalidURL, "Invalid URL port")
                number = number * 10 + Int(byte) - 48
            if number < 1 or number > 65535:
                raise HTTPError(ErrorKind.InvalidURL, "URL port must be between 1 and 65535")
            self._port = number
            if number != (443 if self._scheme == "https" else 80):
                self._authority += ":" + String(number)
        elif authority.endswith(":"):
            raise HTTPError(ErrorKind.InvalidURL, "URL port is empty")
        var fragment = find_byte(text, 35, end)
        var question = min(find_byte(text, 63, end), fragment)
        self._path = _url_component(String(text[byte=end:question]))
        if self._path.byte_length() == 0:
            self._path = "/"
        self._has_query = question < fragment
        self._query = _url_component(String(text[byte=question + 1:fragment]), query=True) if self._has_query else String()

    def scheme(self) -> String:
        return self._scheme

    def host(self) -> String:
        return self._host

    def port(self) -> Int:
        return self._port.value() if self._port else (443 if self._scheme == "https" else 80)

    def path(self) -> String:
        return self._path

    def query(self) -> String:
        return self._query

    def origin(self) -> String:
        return self._scheme + "://" + self._authority

    def query_params(self) raises HTTPError -> QueryParams:
        return QueryParams(self._query)

    def with_query(self, params: QueryParams) raises HTTPError -> Self:
        return Self(self.origin() + self._path + "?" + params.encode())

    def resolve(self, reference: String) raises HTTPError -> Self:
        var fragment = find_byte(reference, 35)
        var target = String(reference[byte=0:fragment])
        var colon = find_byte(target, 58)
        var slash = find_byte(target, 47)
        var question = find_byte(target, 63)
        if colon < min(slash, question):
            return Self(target)
        if target.startswith("//"):
            return Self(self._scheme + ":" + target)
        var path = String(target[byte=0:question])
        var query = String(target[byte=question:]) if question < target.byte_length() else String()
        if path.byte_length() == 0:
            if query.byte_length() == 0 and self._has_query:
                query = "?" + self._query
            return Self(self.origin() + self._path + query)
        if not path.startswith("/"):
            var last = 0
            for i in range(self._path.byte_length()):
                if self._path.as_bytes()[i] == 47:
                    last = i + 1
            path = String(self._path[byte=0:last]) + path
        return Self(self.origin() + _remove_dot_segments(path) + query)

    def __eq__(self, other: Self) -> Bool:
        return self.origin() == other.origin() and self._path == other._path and self._query == other._query and self._has_query == other._has_query

    def __ne__(self, other: Self) -> Bool:
        return not self == other

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.origin(), self._path)
        if self._has_query:
            writer.write("?", self._query)


struct QueryParams(ImplicitlyCopyable, Writable, Sized):
    var _items: MultiItems[False]

    def __init__(out self):
        self._items = MultiItems[False]()

    def __init__(out self, pairs: StringPairs) raises HTTPError:
        self._items = MultiItems[False]()
        for pair in pairs:
            self._items.add(pair[0], pair[1])

    def __init__(out self, pairs: Dict[String, String]) raises HTTPError:
        self._items = MultiItems[False]()
        for entry in pairs.items():
            self._items.add(entry.key, entry.value)

    def __init__(out self, query: String) raises HTTPError:
        self._items = MultiItems[False]()
        if query.byte_length() == 0:
            return
        for entry in query.split("&"):
            var pair = String(entry)
            var split = find_byte(pair, 61)
            var name = percent_decode(String(pair[byte=0:split]), form=True)
            var value = String()
            if split < pair.byte_length():
                value = percent_decode(String(pair[byte=split + 1:]), form=True)
            self._items.add(name, value)

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

    def encode(self, *, form: Bool = False) -> String:
        var result = String()
        for pair in self._items._pairs:
            if result.byte_length() != 0:
                result += "&"
            result += percent_encode(pair[0], form=form) + "=" + percent_encode(pair[1], form=form)
        return result^

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.encode())
