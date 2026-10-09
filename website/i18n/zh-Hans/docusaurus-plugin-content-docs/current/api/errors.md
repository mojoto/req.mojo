---
title: HTTPError 与 ErrorKind
---

# HTTPError 与 ErrorKind

公开 HTTP 操作抛出 HTTPError。ErrorKind 用于区分准备、传输、状态、解码和生命周期错误，无需解析错误文本；这两个类型均不实现自动重试。

```mojo
import req


def main() raises:
    try:
        var response = req.get("https://example.com")
        response.raise_for_status()
    except error:
        if error.kind == req.ErrorKind.HTTPStatusError:
            print(error.status_code.value())
        else:
            print(error.kind, error.message)
```

## `__init__`

用 ErrorKind 和可读 message 构造结构化错误，可选 method、url、status_code 增加上下文，并非所有错误都有这些字段。应用也可显式 raise HTTPError，格式化时输出 kind 和 message。

```text
def __init__(
    out self,
    kind: ErrorKind,
    message: String,
    *,
    method: Optional[String] = None,
    url: Optional[String] = None,
    status_code: Optional[Int] = None,
)
```

## `fields`

程序分支使用 kind，message 是描述文本，不是稳定机器代码。调用 value() 前检查 Optional；HTTPStatusError 通常填充 status_code，传输或校验错误可能没有它。

```text
kind: ErrorKind
message: String
method: Optional[String]
url: Optional[String]
status_code: Optional[Int]
```

## `ErrorKind.InvalidURL`

URL 解析失败、scheme 不支持、authority 错误或查询编码无效。

## `ErrorKind.InvalidRequest`

请求头/方法/请求体无效，请求体格式冲突，超时/认证/Cookie 配置无效，或映射键不存在。

## `ErrorKind.ConnectError`

无法建立传输连接。

## `ErrorKind.ReadError`

接收响应数据时传输失败。

## `ErrorKind.WriteError`

发送请求数据时传输失败。

## `ErrorKind.TLSError`

TLS 握手或证书验证失败。

## `ErrorKind.ProtocolError`

HTTP 状态行、响应头或协议分帧无效。

## `ErrorKind.ConnectTimeout`

建立连接超过配置的阶段超时。

## `ErrorKind.ReadTimeout`

等待响应数据超过配置的超时。

## `ErrorKind.WriteTimeout`

发送请求数据超过配置的超时。

## `ErrorKind.TooManyRedirects`

继续跟随重定向会超过客户端次数上限。

## `ErrorKind.UnsafeRedirect`

跟随重定向会将 HTTPS 降级为 HTTP。

## `ErrorKind.HTTPStatusError`

raise_for_status() 遇到 400–599，普通请求辅助函数不会自动抛出该类型。

## `ErrorKind.DecodeError`

文本字节无效、不支持文本/响应内容编码或解压失败。

## `ErrorKind.JSONDecodeError`

JSON 文档无效、成员/下标不存在或类型访问器不匹配。

## `ErrorKind.ClientClosed`

在已关闭客户端上准备/发送请求或进入上下文。

## `ErrorKind.StreamClosed`

读取传输已关闭且未缓存的流。

## `ErrorKind.StreamNotRead`

对尚未读取的未缓冲响应进行整包访问。

## `ErrorKind.StreamConsumed`

开始分块消费后再进行整包访问。

## 比较与格式化

ErrorKind 支持 `==`、`!=`，用于按错误类别分支。`String(kind)` 或 `print(kind)` 输出类别名称。`String(error)` 或 `print(error)` 输出 `类别: 消息`；不会自动打印可选的 method、url、status_code，需要时单独读取字段。`write_to()` 实现 Writer 协议，一般使用上述格式化操作即可。

```text
# ErrorKind
def __eq__(self, other: Self) -> Bool
def __ne__(self, other: Self) -> Bool
def write_to(self, mut writer: Some[Writer])

# HTTPError
def write_to(self, mut writer: Some[Writer])
```
