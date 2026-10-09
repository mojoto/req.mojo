---
title: HTTP 函数
---

# HTTP 函数

所有辅助函数都接收绝对 `url: String`。`params` 提供查询参数，`headers` 提供请求头。
`auth` 默认为 `Auth.none()`，`timeout` 为每阶段五秒，`follow_redirects=False`，`verify=True`。
`ca_file=None` 使用传输层默认信任库；指定 CA 文件时必须开启证书验证。

支持请求体的方法只能提供 **一种**：`content: Optional[Bytes]` 是原始字节，
`data: Optional[QueryParams]` 是 URL 编码表单，`json: Optional[JSONValue]` 是 JSON。
未显式指定时会补充 JSON/表单的 Content-Type。模块级调用使用独立客户端；需要跨请求复用连接和 Cookie 时使用 [Client](./client.md)。所有网络操作都可能抛出 [HTTPError](./errors.md)。HTTP 4xx/5xx 默认正常返回，调用 `raise_for_status()` 才转为错误。

## 通用参数

| 参数 | 用途与默认行为 |
| --- | --- |
| `url` | 目标绝对 URL，支持 HTTP 和 HTTPS。 |
| `params` | 查询参数，覆盖 URL 中同名参数，保留重复值。 |
| `headers` | 请求头；名称不区分大小写，可保留重复字段。 |
| `content` | 原始请求体字节，默认未提供。 |
| `data` | 表单字段，编码为 `application/x-www-form-urlencoded`。 |
| `json` | JSONValue，序列化为 `application/json`。 |
| `auth` | Basic/Bearer 认证，默认不生成认证头；已有 Authorization 优先。 |
| `timeout` | 连接、读取、写入三个阶段的超时，分别默认 5 秒。 |
| `follow_redirects` | 是否跟随重定向，默认 False。 |
| `verify` | 是否验证 HTTPS 证书，默认 True。 |
| `ca_file` | 自定义 CA 文件路径，默认使用传输层信任库。 |

`get()` 和 `head()` 不接受 `content`、`data`、`json`。其余方法的具体签名见下文。

## `request`

显式指定 HTTP 方法并发送已缓冲请求。`method` 决定操作，`url` 指定目标。
七种标准方法名会转为大写，自定义方法必须是合法 HTTP token。返回 `Response` 前完整读取响应体，因此可立即调用 `text()`、`json()`、`content()`。
适合自定义方法或运行时决定方法的场景。URL/请求体配置无效会抛出 `InvalidURL`/`InvalidRequest`；发送和读取还可能发生传输、超时、TLS、协议或解码错误。

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

读取资源，通过 `params` 传入查询参数，不提供请求体参数。返回完整缓冲的 Response，不自动把响应解析为 JSON。 HTTP 状态与传输错误行为与 `request()` 一致。

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

只读取响应头，不读取响应体，适合检查 Content-Type、Content-Length 等元数据。Req 为 HEAD 暴露空响应体，不会把方法改成 GET。 HTTP 状态与传输错误行为与 `request()` 一致。

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

向目标提交操作或请求体，支持原始字节、表单或 JSON。是否创建资源由服务端决定，Req 不因使用 POST 就判定成功。返回已缓冲的 Response。 HTTP 状态与传输错误行为与 `request()` 一致。

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

发送 PUT，常用于整体替换资源，支持三种请求体格式。Req 发送你指定的方法和请求体，不实现业务层替换逻辑或自动重试。 HTTP 状态与传输错误行为与 `request()` 一致。

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

发送 PATCH，常用于部分更新。补丁格式由服务端定义；需要特定媒体类型的 JSON 补丁，应显式设置 Content-Type。 HTTP 状态与传输错误行为与 `request()` 一致。

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

按服务端 API 语义发送 DELETE。服务端要求时可带请求体。方法名或成功 HTTP 状态本身不证明远程资源已删除，应检查 API 返回结果。 HTTP 状态与传输错误行为与 `request()` 一致。

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

查询服务端支持的操作或 OPTIONS 元数据，可检查 Allow 等响应头。该方法不执行浏览器 CORS 策略，必要时支持请求体。 HTTP 状态与传输错误行为与 `request()` 一致。

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

发起请求，收到响应头后即返回 Response，不等待完整响应体。参数和请求体格式与 `request()` 相同。
返回的响应拥有辅助函数的传输池，函数返回后仍可读取。通过分块读取或 `read()` 消费响应体，并及时关闭响应。
发送成功后，后续读取仍可能失败。消费和生命周期规则见 [Response](./response.md)。

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
