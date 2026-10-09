---
title: API Reference
---

# API reference

Import the public API from `req`. Underscore-prefixed modules are implementation
details. See [source](https://github.com/mojoto/req.mojo/tree/main/req) for full
Mojo signatures.

## Functions

| Function | Result |
| --- | --- |
| `request(method, url, ...)` | Buffered `Response`. |
| `get`, `head`, `post`, `put`, `patch`, `delete`, `options` | Buffered request with the named method. |
| `stream(method, url, ...)` | Unbuffered `Response`. |
| `encode_utf8(text)` | UTF-8 `Bytes`. |

Request options include `params`, `headers`, `auth`, `timeout`,
`follow_redirects`, `verify`, and `ca_file`. `request`, `stream`, and body-bearing
helpers also accept mutually exclusive `content`, `data`, and `json`.
`get` and `head` do not expose those body keywords.

## Client

```text
Client(*, base_url="", headers=Headers(), params=QueryParams(),
       cookies=CookieJar(), auth=Auth.none(), timeout=Timeout(),
       follow_redirects=False, max_redirects=20, verify=True, ca_file=None)
```

Methods: `request`, `stream`, the seven method helpers, `build_request`, `send`,
`context`, `close`, and `is_closed`. Client request methods allow per-request
timeout, redirect, and authentication overrides; TLS settings and redirect
limit are client configuration. `cookies` is the owned mutable CookieJar.

`build_request(method, url, ...)` returns a Request with merged defaults.
`send(request, *, stream=False, timeout=None, follow_redirects=None)` sends it.

## Request and Response

`Request(method, url, *, headers=Headers(), content=None)` stores a method,
URL, headers, and optional bytes. `validate()` checks its invariants.

Response metadata: `status_code`, `reason_phrase`, `http_version`, `url`,
`headers`, and `request`.

| Method | Result |
| --- | --- |
| `content()`, `read()` | `Bytes`; `read()` buffers an untouched stream. |
| `read_chunk(max_bytes=65536)` | `Optional[Bytes]`; `None` at EOF. |
| `text(*, encoding=None)` | `String`. |
| `json()` | `JSONValue`. |
| `is_success()`, `is_redirect()`, `is_closed()` | `Bool`. |
| `raise_for_status()` | Raises for 400–599. |
| `close()` | Closes the transport stream. |

Client and Response are movable resource owners. Contexts borrow those owners;
use `with owner.context() as client` and `with req.stream(...) as body` for closure.

## Value types

| Export | Construction and operations |
| --- | --- |
| `Bytes` | List of unsigned bytes. |
| `Headers` | Empty, string dictionary, or pair list; `get`, `get_all`, indexing, membership, `items`, `add`, `set`, `remove`, `merge`. |
| `QueryParams` | Empty, query string, string dictionary, or pair list; `get`, `get_all`, indexing, membership, `items`, `add`, `set`, `remove`, `merge`; `String(params)` serializes. |
| `URL` | Absolute HTTP(S) URL; `scheme`, `host`, `port`, `path`, `query`, `origin`, `resolve`, `query_params`, `with_query`; `String(url)` serializes. |
| `JSONValue` | String, Int, Float64, Bool, or native JSON Value; `null`, `object`, `array`, `parse`, `to_string`, `set`, `append`, indexing, `is_null`, `string_value`, `int_value`, `float_value`, `bool_value`. |
| `Auth` | `none()`, `basic(username, password)`, `bearer(token)`. |
| `Timeout` | Default 5 seconds per phase; uniform seconds or named `connect`, `read`, `write`; `disabled()` and `validate()`. |
| `CookieJar` | `set`, `get`, `delete`, `clear`, `header`, `extract`. |
| `HTTPError` | `kind`, `message`, optional `method`, `url`, `status_code`. |
| `ErrorKind` | Constants listed in [error handling](./errors.md). |

See the guides for [request bodies](./requests.md), [client defaults](./clients.md),
and [response consumption rules](./streaming.md).
