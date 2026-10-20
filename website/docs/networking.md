---
title: HTTP/2 and Proxies
---

# HTTP/2 and proxies

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

## Explicit proxy

```mojo
import req


def main() raises:
    var owner = req.Client(proxy="http://127.0.0.1:8080")
    with owner.context() as client:
        var response = client.get("https://example.com")
        response.raise_for_status()
        print(response.status_code)
```

HTTP and HTTPS proxy URLs are supported, including credentials in the URL.
HTTPS targets use CONNECT. Certificate verification applies to both the proxy
and the target. An explicit `proxy` takes precedence over environment routing
and bypasses `NO_PROXY`; do not log proxy URLs containing credentials.

## Environment configuration

Environment configuration is opt-in: `trust_env=False` by default.
With `Client(trust_env=True)`, Req reads `HTTP_PROXY`, `HTTPS_PROXY`,
`ALL_PROXY`, and `NO_PROXY`, and their lowercase forms. It also reads
`SSL_CERT_FILE` and `SSL_CERT_DIR` when no explicit `ca_file` is supplied.

Module-level helpers accept `proxy`, `trust_env`, and `limits` too.
Configure [Limits](./api/limits.md) and [Timeout](./api/timeout.md) to bound
connection use and waits. There is no configurable application retry policy
or overall request deadline.
