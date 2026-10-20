---
title: HTTP/2
---

# HTTP/2

## Enable HTTP/2

HTTP/1.1 is enabled by default. Use a persistent Client to enable HTTP/2:

```mojo
import req

def main() raises:
    var owner = req.Client(http2=True)
    with owner.context() as client:
        var response = client.get("https://example.com")
        response.raise_for_status()
        print(response.http_version)
```

With `http1=True, http2=True`, HTTPS negotiates HTTP/2 through ALPN and can
fall back to HTTP/1.1. Set `http1=False, http2=True` for HTTP/2-only mode.
Disabling both protocols raises `InvalidRequest`. Module-level helpers use
HTTP/1.1; use Client or HTTPTransport for protocol selection.

The native libcurl must have HTTP/2 support. HTTP/2-only mode additionally
requires libcurl 8.10 or later. Unsupported configurations fail with
`InvalidRequest` when constructing the client. Req supports connection reuse
and overlapping HTTP/2 response streams; the Client remains single-threaded.

Use [Limits](./api/limits.md) to manage physical connections and
[Timeout.pool](./api/timeout.md) to bound waits for stream capacity.
