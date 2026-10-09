---
title: Error Handling
---

# Error handling

HTTP operations raise `HTTPError`, which carries `kind`, `message`, and optional
`method`, `url`, and `status_code` context. Not every error populates every field.

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

HTTP 4xx/5xx is a normal response until `raise_for_status()` is called. Transport
failures raise during sending or body consumption. A successful header response
does not guarantee that a streamed body can be read completely.

| Kinds | Meaning |
| --- | --- |
| `InvalidURL`, `InvalidRequest` | Invalid URL, headers, body, timeout, or configuration. |
| `ConnectError`, `ReadError`, `WriteError` | Transport failure in the corresponding phase. |
| `ConnectTimeout`, `ReadTimeout`, `WriteTimeout` | Phase timeout. |
| `TLSError`, `ProtocolError` | TLS verification/handshake or HTTP protocol failure. |
| `TooManyRedirects`, `UnsafeRedirect` | Redirect limit or HTTPS downgrade. |
| `HTTPStatusError` | Explicitly raised HTTP 4xx/5xx. |
| `DecodeError`, `JSONDecodeError` | Text/JSON decoding or invalid typed JSON access. |
| `ClientClosed`, `StreamClosed` | Operation on a closed client or stream. |
| `StreamNotRead`, `StreamConsumed` | Whole-body access before buffering or after chunk consumption. |

Req does not automatically retry requests. If your application retries, consider
whether the operation and request body can safely be sent again.
