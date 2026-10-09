---
title: Requests and Responses
---

# Requests and responses

Use `get`, `head`, `post`, `put`, `patch`, `delete`, or `options`, or
`request(method, url)` for an explicit method. Module-level calls use isolated
clients; use a [Client](./clients.md) when you need shared state.

## Query parameters and headers

```mojo
import req


def main() raises:
    var params = req.QueryParams("tag=mojo&tag=http")
    var headers = req.Headers({"Accept": "application/json"})
    var response = req.get(
        "https://httpbin.org/get", params=params, headers=headers
    )
    response.raise_for_status()
    print(response.json().to_string())
```

`QueryParams` accepts a query string, a string dictionary, or a list of string
pairs. It preserves repeated values. `Headers` is case-insensitive and supports
repeated values with `add()` and `get_all()`; `set()` replaces a field.

## JSON, forms, and bytes

```mojo
import req


def main() raises:
    var payload = req.JSONValue.object()
    payload.set("name", req.JSONValue("Mojo"))
    var response = req.post("https://httpbin.org/post", json=payload)
    response.raise_for_status()
    print(response.json().to_string())

    var form = req.QueryParams({"name": "Mojo", "message": "hello world"})
    var submitted = req.post("https://httpbin.org/post", data=form)
    submitted.raise_for_status()

    var raw = req.post(
        "https://httpbin.org/post",
        content=req.encode_utf8("plain text"),
        headers=req.Headers({"Content-Type": "text/plain"}),
    )
    raw.raise_for_status()
```

Supply only one of `json`, `data`, and `content`. Combining them raises
`InvalidRequest`. JSON and form bodies receive an appropriate Content-Type
unless you provide one explicitly. JSON values support parsing, objects, arrays,
scalars, and null; use typed accessors to read values.

## Authentication and timeouts

```mojo
import req


def main() raises:
    var response = req.get(
        "https://example.com/private",
        auth=req.Auth.bearer("your-token"),
        timeout=req.Timeout(connect=3.0, read=10.0, write=10.0),
    )
    print(response.status_code)
```

`Auth.basic(username, password)` creates Basic authentication. `Auth.none()`
disables inherited authentication on an individual client request. An explicit
Authorization header takes precedence over generated authentication.

`Timeout(seconds)` sets all three phases. Values must be finite and positive;
`None` disables a phase and `Timeout.disabled()` disables all three. These are
phase timeouts, rather than one overall request deadline.

## Read a response

`status_code`, `reason_phrase`, `http_version`, `url`, `headers`, and `request`
are available on every response. Buffered requests expose `content()`, `text()`,
and `json()` immediately. Text supports UTF-8, ASCII, and Latin-1; the response
charset is honored, and `text(encoding="utf-8")` overrides it. `json()` decodes
UTF-8 JSON. Call `raise_for_status()` for HTTP 4xx/5xx errors.

See [streaming](./streaming.md) for unbuffered bodies and [errors](./errors.md)
for typed failures.
