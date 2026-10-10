---
title: API 参考
---

# API 参考

从 `req` 导入公开 API。每个页面给出具体签名、参数含义、返回行为、错误条件与示例。先阅读 [快速开始](./getting-started.md) 完成安装和原生传输链接。

## 从任务选择 API

- [HTTP 函数](./api/http.md) — 发送请求和创建响应流。
- [Client](./api/client.md) — 复用连接、应用默认值并准备/发送请求。
- [Request](./api/request.md) — 表示和校验待发送请求。
- [Response](./api/response.md) — 检查元数据、读取响应体、处理状态和关闭流。
- [Headers](./api/headers.md) — 读取、重复、替换和合并 HTTP 字段。
- [QueryParams](./api/query-params.md) — 管理重复参数和查询/表单编码。
- [URL](./api/url.md) — 解析、检查、转换和解析目标引用。
- [JSONValue](./api/json.md) — 构造、解析、修改和读取有类型的 JSON。
- [Auth](./api/auth.md) — 生成 Basic/Bearer 请求头并控制继承。
- [Timeout](./api/timeout.md) — 配置独立的连接/读取/写入超时。
- [CookieJar](./api/cookies.md) — 存储有作用域的 Cookie，并选择或提取它们。
- [HTTPError 与 ErrorKind](./api/errors.md) — 了解每种错误类型和可用上下文。
- [Bytes 与 encode_utf8](./api/bytes.md) — 处理显式字节内容。

## 如何阅读示例

完整示例包含 `import req` 和可抛错的 `def main()`。单独的调用片段假定已经导入 `req`，并位于可抛错函数内。签名保留源码类型和默认值；`mut self` 表示修改持有者。下划线开头的模块不属于应用层 API。

## 三条基本规则

1. 普通请求返回已缓冲响应；`stream()` 收到响应头后返回，需选择整包或分块消费。
2. HTTP 4xx/5xx 默认正常返回；需要状态错误时调用 `raise_for_status()`。
3. Client 与 Response 是可移动资源持有者，用上下文管理关闭，不要隐式复制。
