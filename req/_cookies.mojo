"""Cookie storage and origin-aware request selection."""

from std.ffi import external_call
from std.math import isfinite
from ._exceptions import HTTPError, ErrorKind
from ._urls import URL
from ._headers import Headers
from ._utils import is_token


def _now() -> Float64:
    return Float64(external_call["time", Int](Int(0)))


def _domain_match(host: String, domain: String) -> Bool:
    var numeric = True
    for byte in host.as_bytes():
        if not (48 <= Int(byte) <= 57 or byte == 46):
            numeric = False
    return host == domain or (host.endswith("." + domain) and not numeric)


def _expiry(text: String) -> Optional[Float64]:
    # Accept the standard IMF-fixdate representation of cookie expiration dates.
    var fields = text.replace(",", "").split()
    if len(fields) != 6 or String(fields[5]).upper() != "GMT":
        return None
    var months: List[String] = [
        "jan",
        "feb",
        "mar",
        "apr",
        "may",
        "jun",
        "jul",
        "aug",
        "sep",
        "oct",
        "nov",
        "dec",
    ]
    var month = 0
    for i in range(12):
        if String(fields[2]).lower() == months[i]:
            month = i + 1
    try:
        var day = Int(fields[1])
        var year = Int(fields[3])
        var clock = String(fields[4]).split(":")
        if len(clock) != 3 or month == 0 or not (1 <= day <= 31) or year < 1601:
            return None
        var hour = Int(clock[0])
        var minute = Int(clock[1])
        var second = Int(clock[2])
        if not (0 <= hour < 24 and 0 <= minute < 60 and 0 <= second < 60):
            return None
        year -= Int(month <= 2)
        var era = year // 400
        var yoe = year - era * 400
        var doy = (153 * (month + (-3 if month > 2 else 9)) + 2) // 5 + day - 1
        var days = (
            era * 146097 + yoe * 365 + yoe // 4 - yoe // 100 + doy - 719468
        )
        return Float64(days * 86400 + hour * 3600 + minute * 60 + second)
    except:
        return None


@fieldwise_init
struct _Cookie(ImplicitlyCopyable):
    var name: String
    var value: String
    var domain: String
    var path: String
    var secure: Bool
    var expires: Optional[Float64]
    var host_only: Bool


struct CookieJar(ImplicitlyCopyable):
    var _cookies: List[_Cookie]

    def __init__(out self):
        self._cookies = List[_Cookie]()

    def __init__(out self, *, copy: Self):
        self._cookies = copy._cookies.copy()

    def set(
        mut self,
        name: String,
        value: String,
        *,
        domain: String,
        path: String = "/",
        secure: Bool = False,
        expires: Optional[Float64] = None,
        host_only: Bool = False,
    ) raises HTTPError:
        var normalized = String(domain.lower().strip("."))
        if not is_token(name) or not normalized or not path.startswith("/"):
            raise HTTPError(
                ErrorKind.InvalidRequest, "Invalid cookie name or scope"
            )
        for char in value.as_bytes():
            if char <= 32 or char >= 127 or Int(char) in [34, 44, 59, 92]:
                raise HTTPError(
                    ErrorKind.InvalidRequest, "Invalid cookie value"
                )
        if expires and not isfinite(expires.value()):
            raise HTTPError(
                ErrorKind.InvalidRequest, "Invalid cookie expiration"
            )
        if expires and expires.value() <= _now():
            self.delete(name, domain=normalized, path=path)
            return
        var replacement = _Cookie(
            name, value, normalized, path, secure, expires, host_only
        )
        for i in range(len(self._cookies)):
            if (
                self._cookies[i].name == name
                and self._cookies[i].domain == normalized
                and self._cookies[i].path == path
            ):
                if (
                    self._cookies[i].expires
                    and self._cookies[i].expires.value() <= _now()
                ):
                    self.delete(name, domain=normalized, path=path)
                    break
                self._cookies[i] = replacement
                return
        self._cookies.append(replacement)

    def get(
        self, name: String, *, domain: String, path: String = "/"
    ) -> Optional[String]:
        var normalized = String(domain.lower().strip("."))
        for cookie in self._cookies:
            if (
                cookie.name == name
                and cookie.domain == normalized
                and cookie.path == path
                and (not cookie.expires or cookie.expires.value() > _now())
            ):
                return cookie.value
        return None

    def delete(mut self, name: String, *, domain: String, path: String = "/"):
        var remaining = List[_Cookie]()
        for cookie in self._cookies:
            if not (
                cookie.name == name
                and cookie.domain == domain.lower().strip(".")
                and cookie.path == path
            ):
                remaining.append(cookie)
        swap(self._cookies, remaining)

    def clear(mut self):
        self._cookies.clear()

    def header(self, url: URL) -> Optional[String]:
        var selected = List[_Cookie]()
        for cookie in self._cookies:
            var domain_ok = (
                url.host()
                == cookie.domain if cookie.host_only else _domain_match(
                    url.host(), cookie.domain
                )
            )
            var path_ok = url.path() == cookie.path or (
                url.path().startswith(cookie.path)
                and (
                    cookie.path.endswith("/")
                    or url.path()[byte=cookie.path.byte_length()] == "/"
                )
            )
            if (
                domain_ok
                and path_ok
                and (not cookie.secure or url.scheme() == "https")
                and (not cookie.expires or cookie.expires.value() > _now())
            ):
                selected.append(cookie)
        # Longer paths precede shorter paths, preserving order within one scope.
        for i in range(1, len(selected)):
            var cookie = selected[i]
            var j = i
            while (
                j > 0
                and selected[j - 1].path.byte_length()
                < cookie.path.byte_length()
            ):
                selected[j] = selected[j - 1]
                j -= 1
            selected[j] = cookie
        var result = String()
        for cookie in selected:
            if result:
                result += "; "
            result += cookie.name + "=" + cookie.value
        return result if result else None

    def extract(mut self, headers: Headers, url: URL):
        for line in headers.get_all("Set-Cookie"):
            var fields = line.split(";")
            var pair = String(fields[0]).split("=", maxsplit=1)
            if len(pair) != 2:
                continue
            var domain = url.host()
            var path = String("/")
            var slash = url.path().rfind("/")
            if slash > 0:
                path = String(url.path()[byte=0:slash])
            var secure = False
            var host_only = True
            var valid = True
            var expires: Optional[Float64] = None
            var max_age: Optional[Float64] = None
            for i in range(1, len(fields)):
                var attribute = String(fields[i]).strip().split("=", maxsplit=1)
                var key = String(attribute[0]).lower()
                var value = (
                    String(String(attribute[1]).strip()) if len(attribute)
                    == 2 else String()
                )
                if key == "domain":
                    domain = String(value.lower().strip("."))
                    host_only = False
                    valid = (
                        valid
                        and Bool(domain)
                        and _domain_match(url.host(), domain)
                        and ("." in domain or domain == url.host())
                    )
                elif key == "path" and value.startswith("/"):
                    path = value
                elif key == "secure":
                    secure = True
                elif key == "expires":
                    expires = _expiry(value)
                elif key == "max-age":
                    try:
                        max_age = Float64(Int(value)) + _now()
                    except:
                        pass
            if max_age:
                expires = max_age
            if valid:
                try:
                    self.set(
                        String(String(pair[0]).strip()),
                        String(String(pair[1]).strip().strip('"')),
                        domain=domain,
                        path=path,
                        secure=secure,
                        expires=expires,
                        host_only=host_only,
                    )
                except:
                    pass
