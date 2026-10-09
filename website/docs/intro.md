---
title: Introduction
---

# Req.mojo

Req is a native synchronous HTTP/1.1 client for Mojo. Its Mojo API uses libcurl
through a small native transport bridge.

- HTTP and HTTPS with certificate verification.
- Persistent connections and scoped cookies.
- Query parameters, repeated headers, forms, JSON, and raw bytes.
- Basic and Bearer authentication; separate connect, read, and write timeouts.
- Explicit redirects, streaming responses, and incremental gzip/deflate decoding.

Start with [installation and a first request](./getting-started.md), then read
about [persistent clients](./clients.md) and [streaming](./streaming.md).
The [API reference](./api-reference.md) describes the public exports.

## Defaults and scope

TLS verification is enabled. Each timeout phase defaults to five seconds.
Redirects and automatic retries are disabled; HTTP 4xx/5xx responses return
normally until you call `raise_for_status()`.

This version supports synchronous HTTP/1.1. Async, HTTP/2, multipart, proxies,
and automatic retries are outside its scope. Clients are for single-threaded
use. Cookie handling has no public-suffix database and supports IMF-fixdate
Expires values. Local runtime validation covers macOS ARM64; Linux x86-64
execution remains unverified.

Req is [MIT licensed](https://github.com/mojoto/req.mojo/blob/main/LICENSE).
