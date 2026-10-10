---
title: Request
---

# Request

Use Request when you need to separate request preparation from sending. Import it from req; private request bookkeeping is not part of the API.

```mojo
import req


def main() raises:
    var prepared = req.Request("POST", "https://example.com", content=req.encode_utf8("hello"))
    prepared.validate()
    print(prepared.method)
```

## `Request()`

Build an explicit Request for inspection or Client.send(). `method` is an HTTP
token and `url` must be absolute HTTP(S). Standard method names are normalized
to uppercase. `headers` defaults to empty; optional `content` is raw Bytes and
is copied. This constructor does not encode forms/JSON or apply Client defaults;
use Client.build_request() for that. Construction calls validate(), so invalid
URL or request invariants raise InvalidURL/InvalidRequest before network I/O.

```text
def __init__(
    out self,
    method: String,
    url: String,
    *,
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
) raises HTTPError

def __init__(out self, *, copy: Self)
```

## `validate`

Recheck a Request after mutating its public fields. Reject invalid method tokens,
a body on HEAD, manually supplied Transfer-Encoding, repeated Content-Length,
or a Content-Length that is not exactly the decimal byte count of content.
Returns no value; failure raises InvalidRequest. Client.send() calls this before
each send, including redirects, so editing a Request does not bypass checks.

```text
def validate(self) raises HTTPError
```

## Fields

The outgoing method, target URL, header mapping, and optional raw body. These are request data, not session configuration. Request is implicitly copyable and owns its body data; modifications to one Request do not change already returned Responses.

```text
method: String
url: URL
headers: Headers
content: Optional[Bytes]
```
