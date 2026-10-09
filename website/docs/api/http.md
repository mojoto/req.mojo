---
title: HTTP Functions
---

# HTTP Functions

All helpers take an absolute `url: String`. `params` supplies query values and
`headers` supplies request fields. `auth` defaults to `Auth.none()`, `timeout`
to five seconds per phase, `follow_redirects` to `False`, and `verify` to `True`.
`ca_file=None` uses the transport's default trust store; a custom CA file is
only valid when verification is enabled.

Body-bearing helpers accept **one** of `content: Optional[Bytes]`,
`data: Optional[QueryParams]` (URL-encoded form), or `json: Optional[JSONValue]`.
JSON/form content types are filled in when you did not supply one. Module-level
calls use a fresh client; use [Client](./client.md) for connection and cookie
reuse across calls. Every network operation can raise [HTTPError](./errors.md).
An HTTP 4xx/5xx response is returned normally until `raise_for_status()`.

## Common parameters

| Parameter | Purpose and default behavior |
| --- | --- |
| `url` | Absolute target URL, using HTTP or HTTPS. |
| `params` | Query parameters; replace matching URL parameters and preserve duplicates. |
| `headers` | Request fields with case-insensitive names and repeated values. |
| `content` | Raw request body bytes, omitted by default. |
| `data` | Form fields encoded as `application/x-www-form-urlencoded`. |
| `json` | JSONValue serialized as `application/json`. |
| `auth` | Basic/Bearer authentication, disabled by default; existing Authorization takes precedence. |
| `timeout` | Independent connect, read, and write phase timeouts, each defaulting to 5 seconds. |
| `follow_redirects` | Whether to follow redirects, False by default. |
| `verify` | Whether to validate HTTPS certificates, True by default. |
| `ca_file` | Custom CA file path, otherwise the transport trust store is used. |

`get()` and `head()` do not accept `content`, `data`, or `json`. Exact signatures follow below.

## `request`

Send a buffered request with an explicit HTTP method. `method` selects the
operation and `url` identifies its target. The seven standard method names are
normalized to uppercase; custom methods must still be valid HTTP tokens.
The response body is read completely before a `Response` is returned, so
`text()`, `json()`, and `content()` are immediately available. Use this for
custom methods or when your method is selected at runtime. Invalid URL/body
configuration raises `InvalidURL` or `InvalidRequest`; sending and body reads
can raise transport, timeout, TLS, protocol, or decode errors.

```text
def request(
    method: String,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.request("GET", "https://example.com")
print(response.text())
```

## `get`

Retrieve a resource. Query values go in `params`; this helper has no body keywords. Returns a fully buffered Response. It does not decode JSON automatically. HTTP and transport failure behavior is the same as `request()`.

```text
def get(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.get("https://example.com", params=req.QueryParams({"page": "1"}))
print(response.status_code)
```

## `head`

Retrieve response headers without a response body. Use it to inspect metadata such as Content-Type or Content-Length. Req exposes an empty body for HEAD; it does not convert the method to GET. HTTP and transport failure behavior is the same as `request()`.

```text
def head(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.head("https://example.com")
print(response.headers.get("Content-Type"))
```

## `post`

Submit a new operation or body to the target. Accepts raw content, form data, or JSON. The server defines whether a resource is created; Req does not infer success from the chosen method. Returns a buffered Response. HTTP and transport failure behavior is the same as `request()`.

```text
def post(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.post("https://httpbin.org/post", json=req.JSONValue.parse('{"name":"Mojo"}'))
response.raise_for_status()
```

## `put`

Send a PUT request, commonly used to replace a resource. Accepts the three body formats. Req sends exactly your selected method/body and does not implement an application-level replacement or retry policy. HTTP and transport failure behavior is the same as `request()`.

```text
def put(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.put("https://httpbin.org/put", content=req.encode_utf8("replacement"))
response.raise_for_status()
```

## `patch`

Send a PATCH request, commonly used for partial updates. The server determines the patch format. For a JSON patch document requiring a special media type, supply the Content-Type header explicitly. HTTP and transport failure behavior is the same as `request()`.

```text
def patch(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.patch("https://httpbin.org/patch", json=req.JSONValue.parse('{"name":"updated"}'))
response.raise_for_status()
```

## `delete`

Send DELETE to remove a resource according to the server API. This helper accepts a body if the server requires one. Neither a successful response nor the method name proves a remote resource was deleted; inspect the API response. HTTP and transport failure behavior is the same as `request()`.

```text
def delete(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.delete("https://httpbin.org/delete")
print(response.status_code)
```

## `options`

Ask a server about supported operations or other OPTIONS metadata. Inspect response headers such as Allow; this call does not perform browser CORS policy enforcement. A request body is supported when needed. HTTP and transport failure behavior is the same as `request()`.

```text
def options(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
var response = req.options("https://example.com")
print(response.headers.get("Allow"))
```

## `stream`

Start a request and return a Response after its headers arrive, without reading
the complete body. It accepts the same request options and body formats as
`request()`. The returned response owns the helper's transport pool, so it stays
usable after this function returns. Read chunks or buffer the body with `read()`,
then close the response. Later reads can still fail even when sending succeeded.
See [Response](./response.md) for consumption and lifetime rules.

```text
def stream(
    method: String,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response
```


```mojo
with req.stream("GET", "https://example.com") as body:
    body.raise_for_status()
    while True:
        var chunk = body.read_chunk()
        if not chunk:
            break
        print(len(chunk.value()))
```
