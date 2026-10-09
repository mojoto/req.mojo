"""Request body encoders."""

from ._types import Bytes
from ._utils import encode_utf8
from ._urls import QueryParams
from ._models import Headers
from ._json import JSONValue
from ._exceptions import HTTPError, ErrorKind


def encode_body(
    mut headers: Headers,
    *,
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
) raises HTTPError -> Optional[Bytes]:
    if Int(Bool(content)) + Int(Bool(data)) + Int(Bool(json)) > 1:
        raise HTTPError(ErrorKind.InvalidRequest, "content, data, and json are mutually exclusive")
    if content:
        return content.value().copy()
    if data:
        if "Content-Type" not in headers:
            headers.set("Content-Type", "application/x-www-form-urlencoded")
        return encode_utf8(data.value().encode(form=True))
    if json:
        if "Content-Type" not in headers:
            headers.set("Content-Type", "application/json")
        return encode_utf8(json.value().to_string())
    return None
