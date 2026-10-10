---
title: URL
---

# URL

使用 URL 在不发送请求的情况下检查目标或解析引用。它是可隐式复制的值类型，转换方法返回新值。

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

解析绝对 HTTP/HTTPS URL。其他 scheme、userinfo、缺失 host、非法端口、错误百分号转义、控制字符和反斜杠会抛出 InvalidURL。路径/查询中的 Unicode 字节和部分保留字符进行百分号编码，fragment 不作为请求 URL 发送。不执行 DNS 或网络 I/O。

```text
def __init__(out self, text: String) raises HTTPError
```

```mojo
var target = req.URL("https://example.com:8443/api/users?page=1")
```

## `scheme`

返回归一化的 scheme（http 或 https）String。

```text
def scheme(self) -> String
```

```mojo
print(target.scheme())
```

## `host`

返回解析并归一化的 host String，用于主机匹配；origin() 还包含 scheme 和端口 authority。

```text
def host(self) -> String
```

```mojo
print(target.host())
```

## `port`

返回显式端口；未指定时 HTTPS 为 443、HTTP 为 80。返回 Int，不是 Optional[Int]。

```text
def port(self) -> Int
```

```mojo
print(target.port())
```

## `path`

返回编码后的路径 String；没有路径时表示为 /。绝对 URL 构造保留路径，相对引用解析会移除点段。

```text
def path(self) -> String
```

```mojo
print(target.path())
```

## `query`

返回不带前导 ? 的编码查询字符串；需要解码后的键值访问时使用 query_params()。

```text
def query(self) -> String
```

```mojo
print(target.query())
```

## `origin`

返回 scheme://authority String，包含非默认端口；它用于继承认证和跨 origin 重定向的边界判断。

```text
def origin(self) -> String
```

```mojo
print(target.origin())
```

## `query_params`

把编码后的查询解析为新的 QueryParams，保留重复值。修改它不会修改原 URL，使用 with_query() 创建应用新参数后的 URL。非法转义抛出 InvalidURL；解码后不是有效 UTF-8 时抛出 DecodeError。

```text
def query_params(self) raises HTTPError -> QueryParams
```

```mojo
var search = target.query_params()
print(search.get("page"))
```

## `with_query`

返回保留 origin/path、用 QueryParams 替换查询的新 URL，原 URL 不变。使用标准查询编码而非表单编码，重建时可能抛出 InvalidURL。

```text
def with_query(self, params: QueryParams) raises HTTPError -> Self
```

```mojo
var updated = target.with_query(req.QueryParams({"page": "2"}))
print(String(updated))
```

## `resolve`

相对当前 URL 解析 reference 并返回新 URL。绝对 URL 替换目标，//host 保留 scheme，/path 从 origin 根目录开始，其他路径从基础目录开始。相对解析移除 .. 和 .；只有查询的引用替换查询，空引用保留查询，fragment 被丢弃。目标无效抛出 InvalidURL。

```text
def resolve(self, reference: String) raises HTTPError -> Self
```

```mojo
var base = req.URL("https://example.com/api/")
print(String(base.resolve("users")))
print(String(base.resolve("/users")))
```

## `String(url), equality`

String(url) 序列化归一化后的 URL。== 和 != 比较解析后的 URL 组成部分，不访问或比较远程资源内容。

```text
def __eq__(self, other: Self) -> Bool
def __ne__(self, other: Self) -> Bool
def write_to(self, mut writer: Some[Writer])
```
