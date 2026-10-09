---
title: API 参考
---

# API 参考

从 `req` 导入公开 API。下划线开头的模块是实现细节，完整 Mojo 签名见[源码](https://github.com/mojoto/req.mojo/tree/main/req)。

## 函数

| 函数 | 返回 |
| --- | --- |
| `request(method, url, ...)` | 已缓冲的 `Response`。 |
| `get`、`head`、`post`、`put`、`patch`、`delete`、`options` | 使用对应方法的已缓冲响应。 |
| `stream(method, url, ...)` | 未缓冲的 `Response`。 |
| `encode_utf8(text)` | UTF-8 `Bytes`。 |

请求选项包括 `params`、`headers`、`auth`、`timeout`、`follow_redirects`、`verify`、`ca_file`。`request`、`stream` 及支持请求体的方法还接受互斥的 `content`、`data`、`json`。`get` 和 `head` 不暴露这些请求体参数。

## Client

```text
Client(*, base_url="", headers=Headers(), params=QueryParams(),
       cookies=CookieJar(), auth=Auth.none(), timeout=Timeout(),
       follow_redirects=False, max_redirects=20, verify=True, ca_file=None)
```

方法包括 `request`、`stream`、七种方法辅助函数、`build_request`、`send`、`context`、`close`、`is_closed`。单次请求可覆盖超时、重定向和认证配置；TLS 和重定向次数上限在客户端构造时配置。`cookies` 是持有的可变 CookieJar。

`build_request(method, url, ...)` 返回合并默认值后的 Request。`send(request, *, stream=False, timeout=None, follow_redirects=None)` 发送已经构建的请求。

## Request 和 Response

`Request(method, url, *, headers=Headers(), content=None)` 保存方法、URL、请求头和可选字节，`validate()` 校验约束。

响应元数据：`status_code`、`reason_phrase`、`http_version`、`url`、`headers`、`request`。

| 方法 | 返回 |
| --- | --- |
| `content()`、`read()` | `Bytes`；`read()` 缓冲尚未消费的流。 |
| `read_chunk(max_bytes=65536)` | `Optional[Bytes]`，EOF 返回 `None`。 |
| `text(*, encoding=None)` | `String`。 |
| `json()` | `JSONValue`。 |
| `is_success()`、`is_redirect()`、`is_closed()` | `Bool`。 |
| `raise_for_status()` | 为 400–599 状态抛错。 |
| `close()` | 关闭传输流。 |

Client 和 Response 是可移动的资源持有者。上下文借用这些持有者，用 `with owner.context() as client` 和 `with req.stream(...) as body` 管理关闭。

## 值类型

| 导出 | 构造和操作 |
| --- | --- |
| `Bytes` | 无符号字节列表。 |
| `Headers` | 空、字符串字典、键值对列表；`get`、`get_all`、下标、成员判断、`items`、`add`、`set`、`remove`、`merge`。 |
| `QueryParams` | 空、查询字符串、字符串字典、键值对列表；`get`、`get_all`、下标、成员判断、`items`、`add`、`set`、`remove`、`merge`；`String(params)` 序列化。 |
| `URL` | 绝对 HTTP(S) URL；`scheme`、`host`、`port`、`path`、`query`、`origin`、`resolve`、`query_params`、`with_query`；`String(url)` 序列化。 |
| `JSONValue` | String、Int、Float64、Bool 或原生 JSON Value；`null`、`object`、`array`、`parse`、`to_string`、`set`、`append`、下标、`is_null`、`string_value`、`int_value`、`float_value`、`bool_value`。 |
| `Auth` | `none()`、`basic(username, password)`、`bearer(token)`。 |
| `Timeout` | 默认每阶段 5 秒；统一秒数或命名 `connect`、`read`、`write`；`disabled()` 和 `validate()`。 |
| `CookieJar` | `set`、`get`、`delete`、`clear`、`header`、`extract`。 |
| `HTTPError` | `kind`、`message` 和可选 `method`、`url`、`status_code`。 |
| `ErrorKind` | 见[错误处理](./errors.md)的常量。 |

参阅[请求体](./requests.md)、[客户端默认值](./clients.md)和[响应消费规则](./streaming.md)。
