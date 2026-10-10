---
title: URL
---

# URL

Use URL to inspect targets or resolve references without sending a request. It is an implicitly copyable value; its transformation methods return new values.

```mojo
import req


def main() raises:
    var base = req.URL("https://example.com/api/?page=1")
    var users = base.resolve("users")
    print(String(users))
    print(base.port())
    print(String(base.with_query(req.QueryParams({"page": "2"}))))
```

## `URL()`

Parse an absolute HTTP or HTTPS URL. Other schemes, userinfo, a missing host, invalid port, invalid percent escapes, control characters, and backslashes are rejected with InvalidURL. Unicode path/query bytes and certain reserved characters are percent-encoded; fragments are not sent as part of the URL. It does not perform DNS resolution or network I/O.

```text
def __init__(out self, text: String) raises HTTPError
```

```mojo
var target = req.URL("https://example.com:8443/api/users?page=1")
```

## `scheme`

Return the normalized scheme (http or https) as String.

```text
def scheme(self) -> String
```

```mojo
print(target.scheme())
```

## `host`

Return the parsed host as String, normalized by the URL parser. Use this for host matching; origin() also includes the scheme and port authority.

```text
def host(self) -> String
```

```mojo
print(target.host())
```

## `port`

Return the explicit port or the scheme default: 443 for HTTPS, 80 for HTTP. The result is Int, not Optional[Int].

```text
def port(self) -> Int
```

```mojo
print(target.port())
```

## `path`

Return the encoded path as String. An absent path is represented as /. Absolute URL construction preserves its path; relative resolution removes dot segments.

```text
def path(self) -> String
```

```mojo
print(target.path())
```

## `query`

Return the encoded query without the leading ?. Use query_params() for decoded key/value access.

```text
def query(self) -> String
```

```mojo
print(target.query())
```

## `origin`

Return scheme://authority as String, including a non-default port. This is the boundary used for inherited authentication and cross-origin redirect handling.

```text
def origin(self) -> String
```

```mojo
print(target.origin())
```

## `query_params`

Parse the encoded query into a new QueryParams, preserving duplicates. Mutating it does not mutate this URL; apply with_query() to make a new URL. Malformed escapes raise InvalidURL; decoded bytes that are not UTF-8 raise DecodeError.

```text
def query_params(self) raises HTTPError -> QueryParams
```

```mojo
var search = target.query_params()
print(search.get("page"))
```

## `with_query`

Return a new URL with the same origin/path and the supplied QueryParams replacing its query. The original URL is unchanged. It uses standard query encoding, not form encoding, and can raise InvalidURL during reconstruction.

```text
def with_query(self, params: QueryParams) raises HTTPError -> Self
```

```mojo
var updated = target.with_query(req.QueryParams({"page": "2"}))
print(String(updated))
```

## `resolve`

Resolve a reference relative to this URL and return a new URL. Absolute URLs replace the target; //host keeps the scheme; /path starts at the origin root; other paths start at the base directory. .. and . are removed during relative resolution. A query-only reference replaces the query; an empty reference retains it. Fragments are discarded. Invalid targets raise InvalidURL.

```text
def resolve(self, reference: String) raises HTTPError -> Self
```

```mojo
var base = req.URL("https://example.com/api/")
print(String(base.resolve("users")))
print(String(base.resolve("/users")))
```

## `String(url), equality`

String(url) serializes the normalized URL. == and != compare parsed URL components; they do not contact or compare the contents of remote resources.

```text
def __eq__(self, other: Self) -> Bool
def __ne__(self, other: Self) -> Bool
def write_to(self, mut writer: Some[Writer])
```
