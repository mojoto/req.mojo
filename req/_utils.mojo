"""Byte-oriented HTTP text utilities."""

from ._exceptions import HTTPError, ErrorKind
from std.collections import Dict

comptime Bytes = List[UInt8]
comptime StringPairs = List[Tuple[String, String]]


def encode_utf8(text: String) -> Bytes:
    var result = Bytes(capacity=text.byte_length())
    result.extend(text.as_bytes())
    return result^


def decode_utf8(data: Bytes) raises HTTPError -> String:
    try:
        return String(from_utf8=Span(data))
    except:
        raise HTTPError(ErrorKind.DecodeError, "Invalid UTF-8 bytes")


def find_byte(text: String, byte: Int, start: Int = 0) -> Int:
    for i in range(start, text.byte_length()):
        if Int(text.as_bytes()[i]) == byte:
            return i
    return text.byte_length()


def is_token(text: String) -> Bool:
    if text.byte_length() == 0:
        return False
    for byte in text.as_bytes():
        var c = Int(byte)
        if not (
            48 <= c <= 57
            or 65 <= c <= 90
            or 97 <= c <= 122
            or c
            in [33, 35, 36, 37, 38, 39, 42, 43, 45, 46, 94, 95, 96, 124, 126]
        ):
            return False
    return True


def hex_value(byte: Int) -> Int:
    if 48 <= byte <= 57:
        return byte - 48
    if 65 <= byte <= 70:
        return byte - 55
    if 97 <= byte <= 102:
        return byte - 87
    return -1


def percent_encode(text: String, *, form: Bool = False) -> String:
    var result = String()
    var digits = String("0123456789ABCDEF")
    for byte in text.as_bytes():
        var c = Int(byte)
        if (
            48 <= c <= 57
            or 65 <= c <= 90
            or 97 <= c <= 122
            or c in [45, 46, 95, 126]
        ):
            result += String(chr(c))
        elif c == 32 and form:
            result += "+"
        else:
            result += (
                "%"
                + String(digits[byte = c // 16 : c // 16 + 1])
                + String(digits[byte = c % 16 : c % 16 + 1])
            )
    return result^


def percent_decode(
    text: String, *, form: Bool = False
) raises HTTPError -> String:
    var result = Bytes()
    var i = 0
    while i < text.byte_length():
        var c = Int(text.as_bytes()[i])
        if c == 37:
            if i + 2 >= text.byte_length():
                raise HTTPError(
                    ErrorKind.InvalidURL, "Incomplete percent escape"
                )
            var high = hex_value(Int(text.as_bytes()[i + 1]))
            var low = hex_value(Int(text.as_bytes()[i + 2]))
            if high < 0 or low < 0:
                raise HTTPError(ErrorKind.InvalidURL, "Invalid percent escape")
            result.append(UInt8(high * 16 + low))
            i += 3
        else:
            result.append(UInt8(32 if c == 43 and form else c))
            i += 1
    return decode_utf8(result)


struct MultiItems[ignore_case: Bool](ImplicitlyCopyable, Sized):
    var _pairs: StringPairs

    def __init__(out self):
        self._pairs = StringPairs()

    def __init__(out self, *, copy: Self):
        self._pairs = copy._pairs.copy()

    def __init__(out self, pairs: StringPairs) raises HTTPError:
        self._pairs = StringPairs()
        for pair in pairs:
            self.add(pair[0], pair[1])

    def __init__(out self, pairs: Dict[String, String]) raises HTTPError:
        self._pairs = StringPairs()
        for item in pairs.items():
            self.add(item.key, item.value)

    def _matches(self, left: String, right: String) -> Bool:
        comptime if Self.ignore_case:
            if left == right:
                return True
            var a = left.as_bytes()
            var b = right.as_bytes()
            if len(a) != len(b):
                # Stored header names are ASCII tokens; Unicode lookups keep
                # the existing String.lower() behavior.
                for byte in b:
                    if byte > 127:
                        return left.lower() == right.lower()
                return False
            for i in range(len(a)):
                var x = a[i]
                var y = b[i]
                if x > 127 or y > 127:
                    return left.lower() == right.lower()
                if x >= 65 and x <= 90:
                    x += 32
                if y >= 65 and y <= 90:
                    y += 32
                if x != y:
                    return False
            return True
        else:
            return left == right

    def get(self, name: String) -> Optional[String]:
        for pair in self._pairs:
            if self._matches(pair[0], name):
                return pair[1]
        return None

    def get_all(self, name: String) -> List[String]:
        var result = List[String]()
        for pair in self._pairs:
            if self._matches(pair[0], name):
                result.append(pair[1])
        return result^

    def __contains__(self, name: String) -> Bool:
        return Bool(self.get(name))

    def __getitem__(self, name: String) raises HTTPError -> String:
        var value = self.get(name)
        if not value:
            raise HTTPError(ErrorKind.InvalidRequest, "Missing mapping key")
        return value.value()

    def __len__(self) -> Int:
        return len(self._pairs)

    def items(self) -> StringPairs:
        return self._pairs.copy()

    def add(mut self, name: String, value: String) raises HTTPError:
        comptime if Self.ignore_case:
            if not is_token(name):
                raise HTTPError(
                    ErrorKind.InvalidRequest, "Invalid HTTP header name"
                )
            for byte in value.as_bytes():
                if byte == 10 or byte == 13 or byte == 0:
                    raise HTTPError(
                        ErrorKind.InvalidRequest, "Invalid HTTP header value"
                    )
        self._pairs.append((name, value))

    def set(mut self, name: String, value: String) raises HTTPError:
        var replacement = Self()
        var replaced = False
        for pair in self._pairs:
            if self._matches(pair[0], name):
                if not replaced:
                    replacement.add(name, value)
                    replaced = True
            else:
                replacement.add(pair[0], pair[1])
        if not replaced:
            replacement.add(name, value)
        swap(self._pairs, replacement._pairs)

    def remove(mut self, name: String):
        var result = StringPairs()
        for pair in self._pairs:
            if not self._matches(pair[0], name):
                result.append(pair)
        self._pairs = result^

    def merge(mut self, other: Self) raises HTTPError:
        var visited = List[String]()
        for pair in other._pairs:
            var seen = False
            for name in visited:
                if self._matches(name, pair[0]):
                    seen = True
                    break
            if not seen:
                self.remove(pair[0])
                visited.append(pair[0])
            self.add(pair[0], pair[1])
