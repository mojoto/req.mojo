---
title: Request
---

# Request

需要把准备请求与发送分开时使用 Request，从 req 导入；内部记录字段不属于公开 API。

```mojo
import req


def main() raises:
    var prepared = req.Request("POST", "https://example.com", content=req.encode_utf8("hello"))
    prepared.validate()
    print(prepared.method)
```

## `Request()`

构建供检查或 Client.send() 使用的显式 Request。`method` 是 HTTP token，`url` 必须是绝对 HTTP(S) URL。
标准方法名转为大写；`headers` 默认为空，可选 `content` 是会复制的原始 Bytes。构造器不编码表单/JSON，也不应用 Client 默认值，需要这些能力时使用 Client.build_request()。
构造时调用 validate()，因此 URL 或请求约束无效会在网络 I/O 前抛出 InvalidURL/InvalidRequest。

```text
def __init__(
    out self,
    method: String,
    url: String,
    *,
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
) raises HTTPError

def __init__(out self, *, copy: Self)
```

## `validate`

修改公开字段后重新检查 Request。拒绝非法方法 token、HEAD 请求体、手工 Transfer-Encoding、重复 Content-Length，以及不等于请求体十进制字节数的 Content-Length。
无返回值，失败抛出 InvalidRequest。Client.send() 在每次发送（包括重定向）前调用它，修改 Request 不能绕过校验。

```text
def validate(self) raises HTTPError
```

## 字段

分别是发送方法、目标 URL、请求头和可选原始请求体，属于请求数据，不是会话配置。Request 可隐式复制并拥有请求体；修改某个 Request 不会改变已经返回的 Response。

```text
method: String
url: URL
headers: Headers
content: Optional[Bytes]
```
