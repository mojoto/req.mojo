---
title: Auth
---

# Auth

Auth represents how to generate an Authorization header. It is a copyable value; actual credential transmission happens only when a request is sent.

```mojo
import req


def main() raises:
    var fields = req.Headers()
    var auth = req.Auth.bearer("example-token")
    auth.apply(fields)
    print("Authorization" in fields)
    var owner = req.Client(auth=auth)
    var prepared = owner.build_request("GET", "https://example.com", auth=req.Auth.none())
    print("Authorization" in prepared.headers)
    owner.close()
```

## `Auth()`

Create an empty authentication value, equivalent to Auth.none(). No Authorization header is generated.

```text
def __init__(out self)
```

## `none`

Return a value that generates no Authorization header. On a Client request, explicitly passing Auth.none() disables the inherited auth setting. It does not remove an Authorization header you placed in Headers; remove that header separately.

```text
def none() -> Self
```

```mojo
var response = client.get("private", auth=req.Auth.none())
```

## `basic`

Build HTTP Basic authentication from username and password, encoding username:password as Base64. A username containing : raises InvalidRequest. The value prepares a header; it performs no login request or encryption. Send credentials over verified HTTPS.

```text
def basic(username: String, password: String) raises HTTPError -> Self
```

```mojo
var credentials = req.Auth.basic("username", "password")
```

## `bearer`

Build Authorization: Bearer token. The token must be nonempty printable ASCII without whitespace; otherwise InvalidRequest. No token lookup, refresh, or expiry check is performed.

```text
def bearer(token: String) raises HTTPError -> Self
```

```mojo
var credentials = req.Auth.bearer("your-token")
```

## `apply`

Apply the generated Authorization value to mutable Headers, but only if they do not already contain Authorization. Existing explicit authentication wins. Returns no value; header validation may raise InvalidRequest. Client preparation normally calls this automatically.

```text
def apply(self, mut headers: Headers) raises HTTPError
```

```mojo
var fields = req.Headers()
req.Auth.bearer("your-token").apply(fields)
```
