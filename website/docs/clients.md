---
title: Persistent Clients
---

# Persistent clients

A `Client` reuses connections and stores default headers, query parameters,
authentication, timeouts, and cookies. Clients are for single-threaded use.

```mojo
import req


def main() raises:
    var owner = req.Client(
        base_url="https://httpbin.org/",
        headers=req.Headers({"Accept": "application/json"}),
        timeout=req.Timeout(10.0),
    )
    with owner.context() as client:
        var first = client.get("get")
        first.raise_for_status()
        var second = client.get("headers")
        print(second.json().to_string())
```

`owner.context()` borrows the owning client and closes it when the block exits,
including error paths. You can also use `close()` explicitly; closing twice is
safe. Requests after closure raise `ClientClosed`. Closing a client cancels its
active streamed responses; buffered responses remain readable.

## Base URLs and defaults

Base URLs resolve relative references using URL resolution rules. For example,
`base_url="https://example.com/api/"` and `get("users")` target `/api/users`,
whereas `get("/users")` targets `/users`. Keep the trailing slash when a base URL
represents a directory. Absolute request URLs replace the base URL.

Request headers override matching client headers. Query parameters merge by
key: request values replace client values, and client values replace matching
values in the URL. Repeated values within the winning source are preserved.
Client authentication is applied to the base origin; it is not inherited by a
request to a different origin. Pass an explicit per-request `auth` if needed.

`build_request()` applies client defaults without sending. `send(Request(...))`
sends an already-built request and does not add those request-building defaults.

## Cookies

Server Set-Cookie fields populate the client jar. Cookie selection considers
domain, path, Secure, and expiry. An explicit Cookie header overrides jar cookies.
The owning client exposes `owner.cookies`; a borrowed context exposes
`client.cookies()`. The jar provides `set`, `get`, `delete`, and `clear`.

The jar has no public-suffix database. It is not a browser cookie-policy engine.

## Redirects and TLS

Redirects default to off. Set `follow_redirects=True` on a client or request to
follow them; clients default to `max_redirects=20`. Cross-origin redirects remove
Authorization, Proxy-Authorization, Cookie, and Host, then select jar cookies
for the new URL. HTTPS-to-HTTP redirects raise `UnsafeRedirect`.

301/302 redirect POST to GET, and 303 redirects non-HEAD methods to GET. 307/308
preserve the method and body. Converted requests drop body-related headers.

TLS verification defaults to on. Use `ca_file="/path/to/ca.pem"` for a custom CA.
`verify=False` disables verification; it cannot be combined with a CA file.

## API details

[Client](./api/client.md), [CookieJar](./api/cookies.md), [URL](./api/url.md)
