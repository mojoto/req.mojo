---
title: 请求与响应
---

# 请求与响应

使用 `get`、`head`、`post`、`put`、`patch`、`delete`、`options`，或通过 `request(method, url)` 显式指定方法。模块级调用使用独立客户端；需要共享状态时使用 [Client](./clients.md)。

## 选择请求方式

| 需求 | 使用方式 |
| --- | --- |
| 读取资源或调用查询接口 | `get(url, params=...)` |
| 只检查响应头 | `head(url)` |
| 提交 JSON | `post(url, json=payload)` |
| 提交表单 | `post(url, data=fields)` |
| 发送文件内容或其他原始字节 | `request(method, url, content=bytes)` |
| 多次请求共享默认值和 Cookie | [Client](./clients.md) |
| 响应体较大，需要边读边处理 | [stream()](./streaming.md) |

辅助函数返回 `Response`。HTTP 方法控制请求语义，返回内容的格式由服务端决定；需要 JSON 时显式调用 `response.json()`。


## 查询参数和请求头

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

`QueryParams` 接受查询字符串、字符串字典或字符串键值对列表，保留重复值。`Headers` 的名称不区分大小写，`add()` 和 `get_all()` 支持重复值，`set()` 替换字段。

## JSON、表单和字节

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

`json`、`data`、`content` 只能提供其中一种，组合使用会抛出 `InvalidRequest`。没有显式请求头时，JSON 和表单会设置相应的 Content-Type。JSON 支持解析、对象、数组、标量和 null，通过类型访问器读取值。

## 认证和超时

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

`Auth.basic(username, password)` 创建 Basic 认证。单次客户端请求使用 `Auth.none()` 可禁用继承的认证。显式 Authorization 请求头优先于自动生成的认证头。

`Timeout(seconds)` 设置三个阶段。值必须有限且大于零；`None` 禁用单个阶段，`Timeout.disabled()` 禁用所有阶段。这些配置是各阶段超时，并非整个请求的统一截止时间。

## 读取响应

每个响应都有 `status_code`、`reason_phrase`、`http_version`、`url`、`headers` 和 `request`。普通请求已缓冲响应体，可直接调用 `content()`、`text()` 和 `json()`。文本支持 UTF-8、ASCII 和 Latin-1，采用响应声明的字符集；`text(encoding="utf-8")` 可覆盖。`json()` 解码 UTF-8 JSON。通过 `raise_for_status()` 将 HTTP 4xx/5xx 转为错误。

未缓冲响应体见[流式响应](./streaming.md)，类型化错误见[错误处理](./errors.md)。

## 继续查看 API

- [HTTP 函数](./api/http.md)：各请求方法的完整参数和默认值。
- [Response](./api/response.md)：响应字段、正文读取和状态判断。
- [Headers](./api/headers.md)、[QueryParams](./api/query-params.md)：重复值、查询和修改操作。
- [JSONValue](./api/json.md)：对象、数组和各类型值的读写。
- [Auth](./api/auth.md)、[Timeout](./api/timeout.md)：认证和阶段超时。
