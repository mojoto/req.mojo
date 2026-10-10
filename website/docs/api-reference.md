---
title: API Reference
---

# API Reference

Import the public API from `req`. Each page explains signatures, parameters, returned values, error conditions, and examples. Follow [Getting Started](./getting-started.md) for installation and native transport linking.

## Choose an API for your task

- [HTTP Functions](./api/http.md) — Send requests and start streams.
- [Client](./api/client.md) — Reuse connections, apply defaults, and prepare/send requests.
- [Request](./api/request.md) — Represent and validate an outgoing request.
- [Response](./api/response.md) — Inspect metadata, read bodies, handle status, and close streams.
- [Headers](./api/headers.md) — Read, repeat, replace, and merge HTTP fields.
- [QueryParams](./api/query-params.md) — Manage repeated parameters and query/form encoding.
- [URL](./api/url.md) — Parse, inspect, transform, and resolve targets.
- [JSONValue](./api/json.md) — Construct, parse, mutate, and read typed JSON values.
- [Auth](./api/auth.md) — Generate Basic/Bearer headers and control inheritance.
- [Timeout](./api/timeout.md) — Set independent connect/read/write deadlines.
- [CookieJar](./api/cookies.md) — Store scoped cookies and select or extract them.
- [HTTPError and ErrorKind](./api/errors.md) — Understand individual error kinds and available context.
- [Bytes and encode_utf8](./api/bytes.md) — Work with explicit byte-oriented content.

## Read the examples

Complete examples include `import req` and a raising `def main()`. Short call snippets assume `req` is imported and run inside a raising function. Signatures retain source types and defaults; `mut self` marks mutation of the owner. Underscore-prefixed modules are outside the application API.

## Three core rules

1. Ordinary requests return buffered bodies; `stream()` returns after headers and requires a choice of whole-body or chunk consumption.
2. HTTP 4xx/5xx returns normally; call `raise_for_status()` to require status success.
3. Client and Response are movable owners. Manage closure through contexts and avoid implicit copies.
