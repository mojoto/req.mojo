---
title: Client
---

# Client

Use a Client for a sequence of related requests. It owns a reusable connection pool, session defaults, and cookies. It is movable and intended for single-threaded use. Import with `from req import Client`. Constructors and methods that prepare or send requests raise HTTPError.

## `Client()`

Create a persistent connection pool and session. `base_url` resolves relative
request URLs; keep a trailing slash for a directory base. `headers`, `params`,
`auth`, and `cookies` provide session defaults. `timeout`, `follow_redirects`,
`max_redirects`, `verify`, and `ca_file` control transport behavior.

An empty base URL requires absolute request URLs. `max_redirects` defaults to
20 and must be nonnegative. TLS verification is enabled by default;
`verify=False` cannot be combined with `ca_file`. Invalid configuration raises
`InvalidRequest`. Creating a Client does not contact the server.

```text
def __init__(
    out self,
    *,
    base_url: String = "",
    headers: Headers = Headers(),
    params: QueryParams = QueryParams(),
    cookies: CookieJar = CookieJar(),
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    max_redirects: Int = 20,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError
```


```mojo
var client = req.Client(base_url="https://example.com/api/", timeout=req.Timeout(10.0))
client.close()
```

## `build_request`

Build and validate a Request without network I/O. `method` and `url` identify
the operation; body keywords have the same mutual exclusion as the HTTP helpers.
Client headers are merged with request headers, and request fields win by name.
Query values merge by key: request > client > URL, preserving repeated values
from the winning source. When a base URL is configured, inherited client auth applies only to its origin;
`auth=Auth.none()` explicitly disables inherited auth. Cookie selection uses
the final URL unless you provided a Cookie header. Returns a Request and raises
`ClientClosed`, `InvalidURL`, or `InvalidRequest` when preparation fails.

```text
def build_request(
    self,
    method: String,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
) raises HTTPError -> Request
```


```mojo
var client = req.Client(base_url="https://example.com/api/")
var prepared = client.build_request("GET", "users")
print(String(prepared.url))
client.close()
```

## `send`

Send a prepared Request. Unlike `build_request()`, it does not merge session
headers, parameters, or auth into a manually constructed Request. `stream=False`
buffers the body; `stream=True` returns after headers. `timeout=None` and
`follow_redirects=None` inherit client values; explicit values override them.
Response cookies update the jar. Following redirects applies the redirect and
credential rules from the client guide. Returns a movable Response; a closed
client raises `ClientClosed`, and transport/response parsing errors propagate.

```text
def send(
    mut self,
    request: Request,
    *,
    stream: Bool = False,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```


```mojo
var client = req.Client()
var prepared = client.build_request("GET", "https://example.com")
var response = client.send(prepared)
print(response.text())
client.close()
```

## `request`

Build a request with client defaults, then send it and buffer the body. `method` and `url` choose the request. `params`, `headers`, body keywords, and optional `auth` are passed to `build_request()`; optional `timeout` and `follow_redirects` control this send. Returns a Response. Unlike module-level functions, successive calls share connections and cookies. Call `raise_for_status()` if HTTP 4xx/5xx should be errors.

```text
def request(
    mut self,
    method: String,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `stream`

Build a request with client defaults, then send it as a streamed response. `method` and `url` choose the request. `params`, `headers`, body keywords, and optional `auth` are passed to `build_request()`; optional `timeout` and `follow_redirects` control this send. Returns a Response. Unlike module-level functions, successive calls share connections and cookies. Keep the client open while consuming the stream.

```text
def stream(
    mut self,
    method: String,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `get`

Retrieve a resource. Query values go in `params`; this helper has no body keywords. Returns a fully buffered Response. It does not decode JSON automatically. Applies client defaults through `build_request()` and inherits timeout/redirect settings unless overridden. Status and transport errors follow `Client.request()`.

```text
def get(
    mut self,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `head`

Retrieve response headers without a response body. Use it to inspect metadata such as Content-Type or Content-Length. Req exposes an empty body for HEAD; it does not convert the method to GET. Applies client defaults through `build_request()` and inherits timeout/redirect settings unless overridden. Status and transport errors follow `Client.request()`.

```text
def head(
    mut self,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `post`

The client version of `post()`. Submit a new operation or body to the target. Accepts raw content, form data, or JSON. The server defines whether a resource is created; Req does not infer success from the chosen method. Returns a buffered Response. Applies client defaults through `build_request()` and inherits timeout/redirect settings unless overridden. Status and transport errors follow `Client.request()`.

```text
def post(
    mut self,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `put`

The client version of `put()`. Send a PUT request, commonly used to replace a resource. Accepts the three body formats. Req sends exactly your selected method/body and does not implement an application-level replacement or retry policy. Applies client defaults through `build_request()` and inherits timeout/redirect settings unless overridden. Status and transport errors follow `Client.request()`.

```text
def put(
    mut self,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `patch`

The client version of `patch()`. Send a PATCH request, commonly used for partial updates. The server determines the patch format. For a JSON patch document requiring a special media type, supply the Content-Type header explicitly. Applies client defaults through `build_request()` and inherits timeout/redirect settings unless overridden. Status and transport errors follow `Client.request()`.

```text
def patch(
    mut self,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `delete`

The client version of `delete()`. Send DELETE to remove a resource according to the server API. This helper accepts a body if the server requires one. Neither a successful response nor the method name proves a remote resource was deleted; inspect the API response. Applies client defaults through `build_request()` and inherits timeout/redirect settings unless overridden. Status and transport errors follow `Client.request()`.

```text
def delete(
    mut self,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `options`

The client version of `options()`. Ask a server about supported operations or other OPTIONS metadata. Inspect response headers such as Allow; this call does not perform browser CORS policy enforcement. A request body is supported when needed. Applies client defaults through `build_request()` and inherits timeout/redirect settings unless overridden. Status and transport errors follow `Client.request()`.

```text
def options(
    mut self,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Optional[Auth] = None,
    timeout: Optional[Timeout] = None,
    follow_redirects: Optional[Bool] = None,
) raises HTTPError -> Response
```

## `context`

Borrow this Client for a `with` block. The returned ClientContext delegates
request methods, exposes the jar with `cookies()`, and closes the owning Client
on exit even when the block raises. It does not copy the connection pool.
A closed owner raises `ClientClosed`. Use the original owner to inspect
`is_closed()` or the remaining jar after the block.

```text
def context(mut self) raises HTTPError -> ClientContext[origin_of(self)]
```


```mojo
var owner = req.Client(base_url="https://example.com/")
with owner.context() as client:
    var response = client.get("/")
    print(response.status_code)
print(owner.is_closed())
```

## `close`

Cancel active response streams and release the client's connection pool.
Repeated calls are safe. This returns no value. Later client requests raise
`ClientClosed`, while already buffered response bytes remain available.
Do not close a client before reading an active streaming response.

```text
def close(mut self)
```

## `is_closed`

Return True when the client pool has been released. This checks client ownership state, not whether a particular network connection is alive. It performs no request and raises no HTTPError.

```text
def is_closed(self) -> Bool
```

## `cookies`

The owned session jar. Server responses update it automatically; mutate it directly with CookieJar operations. A borrowed ClientContext uses `cookies()` instead of a field.

```text
cookies: CookieJar
```
