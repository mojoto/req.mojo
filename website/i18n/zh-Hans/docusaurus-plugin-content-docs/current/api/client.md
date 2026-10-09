---
title: Client
---

# Client

多次相关请求使用 Client。它持有可复用连接池、会话默认值和 Cookie，是可移动资源持有者，用于单线程场景。通过 `from req import Client` 导入，准备或发送请求的方法抛出 HTTPError。

## `Client()`

创建持久连接池和会话。`base_url` 用于解析相对请求 URL，表示目录时应保留末尾斜杠。
`headers`、`params`、`auth`、`cookies` 是会话默认值；`timeout`、`follow_redirects`、`max_redirects`、`verify`、`ca_file` 控制传输行为。

基础 URL 为空时，单次请求必须使用绝对 URL。`max_redirects` 默认为 20，不能小于零。默认验证 TLS；`verify=False` 不能与 `ca_file` 同时使用。无效超时、重定向次数或 TLS 配置抛出 `InvalidRequest`；无效基础 URL 抛出 `InvalidURL`。构造客户端本身不会访问服务端。

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

构建并校验 Request，不发生网络 I/O。`method` 和 `url` 指定操作，请求体参数沿用 HTTP 函数的互斥规则。
请求头按名称合并，请求级值覆盖客户端值；查询参数按键采用“请求 > 客户端 > URL”的优先级，保留胜出来源的重复值。
设置了基础 URL 时，客户端认证只继承到该 URL 的 origin，`auth=Auth.none()` 明确禁用继承。未指定 Cookie 头时按最终 URL 选择 jar Cookie。
返回 Request，准备失败时可能抛出 `ClientClosed`、`InvalidURL` 或 `InvalidRequest`。

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

发送已构建的 Request。手动构造的 Request 不会在这里再次补充会话请求头、查询参数或认证。
`stream=False` 缓冲完整响应体，`stream=True` 收到头后返回。`timeout=None` 和 `follow_redirects=None` 继承客户端设置，显式值覆盖设置。
响应 Cookie 更新 jar；重定向采用客户端指南中的方法转换和凭据处理规则。返回可移动的 Response；已关闭客户端抛出 `ClientClosed`，传输和响应解析错误继续向外抛出。

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

应用客户端默认值构建请求，发送并缓冲完整响应体。 `method` 和 `url` 指定请求；`params`、`headers`、请求体和可选 `auth` 交给 `build_request()`，可选 `timeout` 和 `follow_redirects` 控制本次发送。返回 Response。与模块函数不同，多次调用共享连接和 Cookie。需要把 HTTP 4xx/5xx 视为错误时调用 `raise_for_status()`。

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

应用客户端默认值构建请求，发送后返回流式响应。 `method` 和 `url` 指定请求；`params`、`headers`、请求体和可选 `auth` 交给 `build_request()`，可选 `timeout` 和 `follow_redirects` 控制本次发送。返回 Response。与模块函数不同，多次调用共享连接和 Cookie。消费流期间保持客户端开启。

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

客户端版本的 `get()`。读取资源，通过 `params` 传入查询参数，不提供请求体参数。返回完整缓冲的 Response，不自动把响应解析为 JSON。 通过 `build_request()` 应用客户端默认值；未覆盖时继承超时和重定向配置。返回 Response，状态和传输错误与 `Client.request()` 一致。

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

客户端版本的 `head()`。只读取响应头，不读取响应体，适合检查 Content-Type、Content-Length 等元数据。Req 为 HEAD 暴露空响应体，不会把方法改成 GET。 通过 `build_request()` 应用客户端默认值；未覆盖时继承超时和重定向配置。返回 Response，状态和传输错误与 `Client.request()` 一致。

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

客户端版本的 `post()`。向目标提交操作或请求体，支持原始字节、表单或 JSON。是否创建资源由服务端决定，Req 不因使用 POST 就判定成功。返回已缓冲的 Response。 通过 `build_request()` 应用客户端默认值；未覆盖时继承超时和重定向配置。返回 Response，状态和传输错误与 `Client.request()` 一致。

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

客户端版本的 `put()`。发送 PUT，常用于整体替换资源，支持三种请求体格式。Req 发送你指定的方法和请求体，不实现业务层替换逻辑或自动重试。 通过 `build_request()` 应用客户端默认值；未覆盖时继承超时和重定向配置。返回 Response，状态和传输错误与 `Client.request()` 一致。

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

客户端版本的 `patch()`。发送 PATCH，常用于部分更新。补丁格式由服务端定义；需要特定媒体类型的 JSON 补丁，应显式设置 Content-Type。 通过 `build_request()` 应用客户端默认值；未覆盖时继承超时和重定向配置。返回 Response，状态和传输错误与 `Client.request()` 一致。

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

客户端版本的 `delete()`。按服务端 API 语义发送 DELETE。服务端要求时可带请求体。方法名或成功 HTTP 状态本身不证明远程资源已删除，应检查 API 返回结果。 通过 `build_request()` 应用客户端默认值；未覆盖时继承超时和重定向配置。返回 Response，状态和传输错误与 `Client.request()` 一致。

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

客户端版本的 `options()`。查询服务端支持的操作或 OPTIONS 元数据，可检查 Allow 等响应头。该方法不执行浏览器 CORS 策略，必要时支持请求体。 通过 `build_request()` 应用客户端默认值；未覆盖时继承超时和重定向配置。返回 Response，状态和传输错误与 `Client.request()` 一致。

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

为 `with` 代码块借用 Client，返回 ClientContext。上下文转发请求方法，用 `cookies()` 访问 jar，并在退出时关闭持有者，包括异常路径。
不会复制连接池。已关闭持有者抛出 `ClientClosed`。退出后可通过原持有者检查 `is_closed()` 或查看剩余 Cookie。

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

取消活动响应流并释放连接池，无返回值，重复调用安全。后续客户端请求抛出 `ClientClosed`，已缓冲响应的字节仍可读取。
不要在读取活动流式响应前关闭客户端。

```text
def close(mut self)
```

## `is_closed`

连接池已释放时返回 True。检查的是客户端持有状态，不是某条网络连接是否存活；不发起请求，不抛出 HTTPError。

```text
def is_closed(self) -> Bool
```

## `cookies`

客户端持有的会话 CookieJar，服务端响应自动更新它，也可直接调用 CookieJar 方法修改。借用的 ClientContext 使用 `cookies()` 方法访问。

```text
cookies: CookieJar
```
