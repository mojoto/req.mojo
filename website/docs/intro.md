---
title: Introduction
---

# Req.mojo

Req is a native synchronous HTTP client for Mojo, using libcurl through a small
native transport bridge.

- HTTP/1.1 and opt-in HTTP/2, with verified HTTPS.
- Persistent connections, pool limits, and scoped cookies.
- Query parameters, repeated headers, forms, JSON, bytes, and multipart uploads.
- File uploads without whole-file buffering.
- Basic/Bearer authentication and connect/read/write/pool timeouts.
- Redirect history, prepared next requests, and response timing.
- Streaming bytes, text, and lines, plus incremental gzip/deflate decoding.
- Request/response hooks and injectable HTTP, mock, and custom transports.

Start with [installation](./getting-started.md), then
[persistent clients](./clients.md), [HTTP/2](./http2.md), [proxies](./proxies.md),
and [streaming](./streaming.md). The [API reference](./api-reference.md) describes
the public types and methods.

## Defaults and scope

TLS verification is enabled. Connect, read, write, and pool timeouts each
default to five seconds. Redirects, HTTP/2, and environment configuration
(`trust_env`) are opt-in. HTTP 4xx/5xx returns normally until
`raise_for_status()`.

Clients are for single-threaded use. Async, HTTP/3, configurable application
retries, and a total request deadline are not provided. Cookie handling has no
public-suffix database and supports IMF-fixdate Expires values.

CI runs tests, precompilation, and isolated consumer checks on Linux x86-64,
Linux ARM64, and macOS ARM64. HTTP/2 requires a capable libcurl build;
HTTP/2-only mode requires libcurl 8.10 or later.

Req is [MIT licensed](https://github.com/mojoto/req.mojo/blob/main/LICENSE).
