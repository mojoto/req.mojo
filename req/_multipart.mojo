"""Multipart file descriptions and streaming form encoding."""

from std.ffi import external_call, c_int
from ._body import RequestBody
from ._types import Bytes
from ._urls import QueryParams
from ._utils import encode_utf8, is_token
from ._exceptions import HTTPError, ErrorKind


struct UploadFile(ImplicitlyCopyable):
    var name: String
    var filename: String
    var content_type: String
    var body: RequestBody

    def __init__(
        out self,
        name: String,
        path: String,
        *,
        filename: Optional[String] = None,
        content_type: String = "application/octet-stream",
    ) raises HTTPError:
        var components = path.split("/")
        self.name = name
        self.filename = filename.value() if filename else String(
            components[len(components) - 1]
        )
        self.content_type = content_type
        self.body = RequestBody.from_file(path)
        self._validate()

    @staticmethod
    def from_bytes(
        name: String,
        content: Bytes,
        *,
        filename: String = "upload",
        content_type: String = "application/octet-stream",
    ) raises HTTPError -> Self:
        return Self(
            name,
            RequestBody.from_bytes(content),
            filename=filename,
            content_type=content_type,
        )

    def __init__(
        out self,
        name: String,
        body: RequestBody,
        *,
        filename: String = "upload",
        content_type: String = "application/octet-stream",
    ) raises HTTPError:
        self.name = name
        self.filename = filename
        self.content_type = content_type
        self.body = body
        self._validate()

    def _validate(self) raises HTTPError:
        _ = _quote(self.name)
        _ = _quote(self.filename)
        for byte in self.content_type.as_bytes():
            if byte < 32 or byte >= 127:
                raise HTTPError(
                    ErrorKind.InvalidRequest, "Invalid multipart content type"
                )
        if not self.content_type:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Empty multipart content type"
            )


def _quote(value: String) raises HTTPError -> String:
    for byte in value.as_bytes():
        if byte < 32 and byte != 10 and byte != 13:
            raise HTTPError(ErrorKind.InvalidRequest, "Invalid multipart field")
        if byte == 127:
            raise HTTPError(ErrorKind.InvalidRequest, "Invalid multipart field")
    return (
        value.replace("\\", "\\\\")
        .replace('"', "%22")
        .replace("\r", "%0D")
        .replace("\n", "%0A")
    )


def _boundary() raises HTTPError -> String:
    var bytes = Bytes(length=16, fill=0)
    var path = String("/dev/urandom")
    var fd = external_call["open", c_int](
        path.as_c_string_span().ptr(), c_int(0)
    )
    if fd < 0:
        raise HTTPError(
            ErrorKind.WriteError, "Cannot generate multipart boundary"
        )
    var count = external_call["read", Int](fd, bytes.unsafe_ptr(), len(bytes))
    _ = external_call["close", c_int](fd)
    if count != len(bytes):
        raise HTTPError(
            ErrorKind.WriteError, "Cannot generate multipart boundary"
        )
    var result = String()
    var digits = String("0123456789abcdef")
    for byte in bytes:
        result += String(digits[byte=Int(byte) >> 4]) + String(
            digits[byte=Int(byte) & 15]
        )
    return result


def encode_multipart(
    data: QueryParams,
    files: List[UploadFile],
    boundary: Optional[String] = None,
) raises HTTPError -> Tuple[RequestBody, String]:
    var token = boundary.value() if boundary else _boundary()
    var valid = Bool(token) and token.byte_length() <= 70
    for byte in token.as_bytes():
        valid = valid and (
            UInt8(48) <= byte <= UInt8(57)
            or UInt8(65) <= byte <= UInt8(90)
            or UInt8(97) <= byte <= UInt8(122)
            or byte in String("'()+_,-./:=?").as_bytes()
        )
    if not valid:
        raise HTTPError(ErrorKind.InvalidRequest, "Invalid multipart boundary")
    var body = RequestBody()
    for pair in data.items():
        body._add(
            encode_utf8(
                "--"
                + token
                + '\r\nContent-Disposition: form-data; name="'
                + _quote(pair[0])
                + '"\r\n\r\n'
                + pair[1]
                + "\r\n"
            )
        )
    for file in files:
        file._validate()
        body._add(
            encode_utf8(
                "--"
                + token
                + '\r\nContent-Disposition: form-data; name="'
                + _quote(file.name)
                + '"; filename="'
                + _quote(file.filename)
                + '"\r\nContent-Type: '
                + file.content_type
                + "\r\n\r\n"
            )
        )
        body._append(file.body)
        body._add(encode_utf8("\r\n"))
    body._add(encode_utf8("--" + token + "--\r\n"))
    return (body, token)


def multipart_boundary(
    content_type: Optional[String],
) raises HTTPError -> Optional[String]:
    if not content_type:
        return None
    var parts = content_type.value().split(";")
    if String(parts[0]).strip().lower() != "multipart/form-data":
        raise HTTPError(
            ErrorKind.InvalidRequest, "files require multipart/form-data"
        )
    var found: Optional[String] = None
    for parameter in parts[1:]:
        var pair = String(parameter).strip().split("=", maxsplit=1)
        if len(pair) == 2 and String(pair[0]).strip().lower() == "boundary":
            if found:
                raise HTTPError(
                    ErrorKind.InvalidRequest, "Duplicate multipart boundary"
                )
            var value = String(String(pair[1]).strip())
            if value.startswith('"') or value.endswith('"'):
                if (
                    not (value.startswith('"') and value.endswith('"'))
                    or value.byte_length() < 2
                ):
                    raise HTTPError(
                        ErrorKind.InvalidRequest,
                        "Invalid quoted multipart boundary",
                    )
                found = String(value.strip('"'))
            else:
                if not is_token(value):
                    raise HTTPError(
                        ErrorKind.InvalidRequest,
                        "Invalid unquoted multipart boundary",
                    )
                found = String(value)
    if found:
        return found
    raise HTTPError(ErrorKind.InvalidRequest, "Missing multipart boundary")
