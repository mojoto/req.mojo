---
title: HTTPError and ErrorKind
---

# HTTPError and ErrorKind

Public HTTP operations raise HTTPError. ErrorKind lets you distinguish preparation, transport, status, decode, and lifetime failures without parsing error text. Neither type implements an automatic retry policy.

```mojo
import req


def main() raises:
    try:
        var response = req.get("https://example.com")
        response.raise_for_status()
    except error:
        if error.kind == req.ErrorKind.HTTPStatusError:
            print(error.status_code.value())
        else:
            print(error.kind, error.message)
```

## `__init__`

Construct a structured failure with an ErrorKind and human-readable message. Optional method, url, and status_code add context; not all errors have all three. Application code can also raise HTTPError explicitly. Formatting the error prints its kind and message.

```text
def __init__(
    out self,
    kind: ErrorKind,
    message: String,
    *,
    method: Optional[String] = None,
    url: Optional[String] = None,
    status_code: Optional[Int] = None,
)
```

## `fields`

Branch on kind for program logic. message is descriptive text, not a stable machine-readable code. Check an Optional before value(); status_code is normally populated for HTTPStatusError but may be absent for transport or validation failures.

```text
kind: ErrorKind
message: String
method: Optional[String]
url: Optional[String]
status_code: Optional[Int]
```

## `ErrorKind.InvalidURL`

URL parsing, unsupported scheme, malformed authority, or invalid encoded query.

## `ErrorKind.InvalidRequest`

Invalid headers/method/body, conflicting body formats, invalid timeout/auth/cookie configuration, or a missing mapping key.

## `ErrorKind.ConnectError`

Could not establish the transport connection.

## `ErrorKind.ReadError`

Transport failed while receiving response data.

## `ErrorKind.WriteError`

Transport failed while sending request data.

## `ErrorKind.TLSError`

TLS handshake or certificate validation failed.

## `ErrorKind.ProtocolError`

Invalid HTTP status line, response headers, or protocol framing.

## `ErrorKind.ConnectTimeout`

Connection establishment exceeded its configured phase timeout.

## `ErrorKind.ReadTimeout`

Waiting for response data exceeded its configured timeout.

## `ErrorKind.WriteTimeout`

Sending request data exceeded its configured timeout.

## `ErrorKind.TooManyRedirects`

Following a redirect would exceed the client redirect limit.

## `ErrorKind.UnsafeRedirect`

A followed redirect would downgrade HTTPS to HTTP.

## `ErrorKind.HTTPStatusError`

raise_for_status() found a 400–599 response; ordinary request helpers do not raise this automatically.

## `ErrorKind.DecodeError`

Invalid text bytes, unsupported text encoding, unsupported response content encoding, or decompression failure.

## `ErrorKind.JSONDecodeError`

Invalid JSON document, absent JSON member/index, or a mismatched typed JSON accessor.

## `ErrorKind.ClientClosed`

Preparing/sending a request or entering a context on a closed client.

## `ErrorKind.StreamClosed`

Reading an uncached stream whose transport has been closed.

## `ErrorKind.StreamNotRead`

Whole-body access on an untouched unbuffered response.

## `ErrorKind.StreamConsumed`

Whole-body access after chunk consumption has started.

## Comparison and formatting

ErrorKind supports `==` and `!=` for branching by failure category. `String(kind)` or `print(kind)` writes its name. `String(error)` or `print(error)` writes `Kind: message`; optional method, url, and status_code are read separately. `write_to()` implements the Writer protocol; normal applications use these formatting operations.

```text
# ErrorKind
def __eq__(self, other: Self) -> Bool
def __ne__(self, other: Self) -> Bool
def write_to(self, mut writer: Some[Writer])

# HTTPError
def write_to(self, mut writer: Some[Writer])
```
