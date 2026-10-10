---
title: Auth
---

# Auth

Auth 表示 Authorization 请求头的生成方式，是可复制的值；发送请求时才会传输凭据。

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

创建空认证值，等同 Auth.none()，不生成 Authorization 头。

```text
def __init__(out self)
```

## `none`

返回不生成 Authorization 头的值。单次 Client 请求显式传入 Auth.none() 可禁用继承的 auth，但不移除 Headers 中你显式设置的 Authorization，应单独删除该头。

```text
def none() -> Self
```

```mojo
var response = client.get("private", auth=req.Auth.none())
```

## `basic`

以 username 和 password 构建 HTTP Basic，Base64 编码 username:password。username 包含 : 时抛出 InvalidRequest。此值只是准备请求头，不发起登录或加密操作，凭据应通过验证证书的 HTTPS 发送。

```text
def basic(username: String, password: String) raises HTTPError -> Self
```

```mojo
var credentials = req.Auth.basic("username", "password")
```

## `bearer`

构建 Authorization: Bearer token。token 必须为非空、无空白的可打印 ASCII，否则抛出 InvalidRequest。不执行 token 查询、刷新或有效期检查。

```text
def bearer(token: String) raises HTTPError -> Self
```

```mojo
var credentials = req.Auth.bearer("your-token")
```

## `apply`

把生成的 Authorization 值应用到可变 Headers，仅在不存在该头时设置，显式认证头优先。无返回值，头校验可能抛出 InvalidRequest。客户端准备请求时通常自动调用。

```text
def apply(self, mut headers: Headers) raises HTTPError
```

```mojo
var fields = req.Headers()
req.Auth.bearer("your-token").apply(fields)
```
