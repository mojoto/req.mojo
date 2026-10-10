---
title: CookieJar
---

# CookieJar

CookieJar stores session cookies with domain, path, security, and expiry scope. It is not a browser cookie-policy engine. Client request preparation uses it unless an explicit Cookie header is supplied.

```mojo
import req


def main() raises:
    var jar = req.CookieJar()
    jar.set("session", "example", domain="example.com", secure=True, host_only=True)
    print(jar.get("session", domain="example.com").value())
    print(jar.header(req.URL("https://example.com/")))
    jar.delete("session", domain="example.com")
    print(jar.header(req.URL("https://example.com/")))
```

## `CookieJar()`

Construct an empty session jar. Copying a CookieJar copies its stored cookie values rather than sharing a mutable jar. A Client owns a jar and extracts response cookies automatically.

```text
def __init__(out self)

def __init__(out self, *, copy: Self)
```

## `set`

Store a cookie identified by name, domain, and path, replacing the existing cookie with the same identity. domain is required, lowercased, and stripped of leading/trailing dots. path defaults to / and must begin with /. secure restricts selection to HTTPS; host_only restricts it to the exact host. expires is an optional finite Unix timestamp in seconds; a past expiry removes rather than stores the cookie. Invalid name, value, scope, or expiry raises InvalidRequest.

```text
def set(
    mut self,
    name: String,
    value: String,
    *,
    domain: String,
    path: String = "/",
    secure: Bool = False,
    expires: Optional[Float64] = None,
    host_only: Bool = False,
) raises HTTPError
```

```mojo
jar.set("session", "example", domain="example.com", secure=True, host_only=True)
```

## `get`

Look up one cookie by exact name, normalized domain, and exact path (default /). Return Optional[String] for its unexpired value, or None. This is an exact jar lookup, not URL-based domain/path selection; use header(url) for outgoing selection.

```text
def get(
    self, name: String, *, domain: String, path: String = "/"
) -> Optional[String]
```

```mojo
var session = jar.get("session", domain="example.com")
if session:
    print(session.value())
```

## `delete`

Delete the exact name/domain/path identity. Missing cookies are a no-op. The domain is normalized the same way as set/get. Returns no value and does not raise for absence.

```text
def delete(mut self, name: String, *, domain: String, path: String = "/")
```

```mojo
jar.delete("session", domain="example.com")
```

## `clear`

Remove every stored cookie from this jar. This does not close a Client or its connections. It returns no value.

```text
def clear(mut self)
```

```mojo
jar.clear()
```

## `header`

Select unexpired cookies matching a URL and return a Cookie header value as Optional[String]. Domain/subdomain, path boundaries, host_only, and Secure are checked. Longer matching paths appear first; order is preserved within a scope. No applicable cookies returns None. It returns the value, without the Cookie: field name.

```text
def header(self, url: URL) -> Optional[String]
```

```mojo
var value = jar.header(req.URL("https://example.com/account"))
if value:
    print(value.value())
```

## `extract`

Read all Set-Cookie values from Headers using url as the response origin. Missing Domain creates a host-only cookie; a default path is derived from the response URL. Domain, Path, Secure, Expires, and Max-Age are handled; valid Max-Age takes precedence over Expires. Malformed or out-of-scope cookie entries are ignored rather than raised to the caller. Expires supports IMF-fixdate, and there is no public-suffix database.

```text
def extract(mut self, headers: Headers, url: URL)
```

```mojo
var fields = req.Headers({"Set-Cookie": "session=example; Path=/; Secure"})
jar.extract(fields, req.URL("https://example.com/login"))
```
