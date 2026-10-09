"""Basic and Bearer authentication values."""

from std.base64 import b64encode
from ._models import Headers
from ._exceptions import HTTPError, ErrorKind


struct Auth(ImplicitlyCopyable):
    var _header: Optional[String]

    def __init__(out self):
        self._header = None

    @staticmethod
    def none() -> Self:
        return Self()

    @staticmethod
    def basic(username: String, password: String) raises HTTPError -> Self:
        if ":" in username:
            raise HTTPError(
                ErrorKind.InvalidRequest,
                "Basic authentication username cannot contain a colon",
            )
        var result = Self()
        result._header = "Basic " + b64encode(username + ":" + password)
        return result^

    @staticmethod
    def bearer(token: String) raises HTTPError -> Self:
        if token.byte_length() == 0:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Bearer token cannot be empty"
            )
        for byte in token.as_bytes():
            if byte <= 32 or byte >= 127:
                raise HTTPError(
                    ErrorKind.InvalidRequest, "Invalid Bearer token"
                )
        var result = Self()
        result._header = "Bearer " + token
        return result^

    def apply(self, mut headers: Headers) raises HTTPError:
        if self._header and "Authorization" not in headers:
            headers.set("Authorization", self._header.value())
