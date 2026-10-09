---
title: CookieJar
---

# CookieJar

CookieJar 按 domain、path、安全和有效期范围存储会话 Cookie，不是浏览器 Cookie 策略引擎。未显式指定 Cookie 请求头时，Client 准备请求会使用 jar。

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

创建空会话 jar。复制 CookieJar 会复制存储的 Cookie 值，不共享同一个可变 jar。Client 持有 jar 并自动提取响应 Cookie。

```text
def __init__(out self)

def __init__(out self, *, copy: Self)
```

## `set`

按 name/domain/path 保存 Cookie，替换同身份的旧值。domain 必填，转为小写并去除首尾点；path 默认为 /，必须以 / 开头。secure 限制只向 HTTPS 选择，host_only 限制精确主机。expires 是可选的有限 Unix 秒时间戳，过去时间会删除而非保存 Cookie。名称、值、作用域或过期时间无效抛出 InvalidRequest。

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

按精确 name、归一化 domain 和精确 path（默认 /）查找一个 Cookie，返回未过期值的 Optional[String]，否则 None。这是 jar 精确查找，不是基于 URL 的 domain/path 选择；发送选择使用 header(url)。

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

删除精确 name/domain/path 身份的 Cookie；不存在时不操作，domain 与 set/get 一样归一化。无返回值，不因缺失抛错。

```text
def delete(mut self, name: String, *, domain: String, path: String = "/")
```

```mojo
jar.delete("session", domain="example.com")
```

## `clear`

删除 jar 的所有 Cookie，不关闭 Client 或连接，无返回值。

```text
def clear(mut self)
```

```mojo
jar.clear()
```

## `header`

为 URL 选择未过期 Cookie，返回 Cookie 头值的 Optional[String]。检查 domain/子域、路径边界、host_only 和 Secure，较长匹配路径优先，同作用域内保留顺序。没有适用项时返回 None；只返回值，不含 Cookie: 字段名。

```text
def header(self, url: URL) -> Optional[String]
```

```mojo
var value = jar.header(req.URL("https://example.com/account"))
if value:
    print(value.value())
```

## `extract`

以 url 为响应来源解析 Headers 中所有 Set-Cookie。无 Domain 时创建 host-only Cookie，默认 path 从响应 URL 推导。处理 Domain、Path、Secure、Expires、Max-Age，有效 Max-Age 优先于 Expires。格式错误或越界项被忽略，不向调用方抛错。Expires 支持 IMF-fixdate，没有公共后缀数据库。

```text
def extract(mut self, headers: Headers, url: URL)
```

```mojo
var fields = req.Headers({"Set-Cookie": "session=example; Path=/; Secure"})
jar.extract(fields, req.URL("https://example.com/login"))
```
