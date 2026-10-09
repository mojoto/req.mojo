# req.mojo 核心接口设计

req.mojo 采用 requests 的便捷调用方式和 HTTPX 的 `Client` 组织方式：少量请求直接调用 `req.get()`，需要连接复用、公共配置和 Cookie 会话时使用 `Client`。公共接口使用 Mojo 原生类型，调用方不需要 Python 运行时。

同步第一版已按此契约实现。下文的签名省略函数体、部分重载和所有权参数，用于说明接口；可编译示例见 `examples/`。实现使用 Mojo 1.1.0、原生 libcurl HTTP/1.1 后端和通过 Pixi Git 依赖安装的 `ehsanmok/json` v0.4.1，HTTP 与 JSON 调用不依赖 Python 运行时。

## 1. API 取舍

| 关注点 | requests | HTTPX | req.mojo 草案 |
| --- | --- | --- | --- |
| 简单请求 | `requests.get()` | `httpx.get()` | `req.get()` 等便捷函数 |
| 持久客户端 | `Session` | `Client` | 只提供 `Client`，避免同义入口 |
| 原始请求体 | `data=` 兼容多种内容 | `content=` 与表单 `data=` 分开 | `content=` 字节，`data=` 表单，`json=` JSON 值 |
| 默认超时 | 未指定时无超时 | 默认 5 秒 | 默认各 I/O 阶段 5 秒 |
| 默认重定向 | 通常跟随，HEAD 例外 | 默认不跟随 | 所有方法默认不跟随 |
| 状态判断 | `ok` 包含部分非 2xx 状态 | `is_success` 明确表示 2xx | `is_success()` 明确表示 2xx |
| 状态错误 | `raise_for_status()` 处理 4xx/5xx | `raise_for_status()` 处理非 2xx | 处理 4xx/5xx；3xx 可正常检查 |
| 流式响应 | `stream=True` | 独立 `stream()` 入口 | 常用调用使用 `stream()`，底层 `send()` 支持 `stream=True` |

两库的入口与行为依据分别见 [Requests API](https://requests.readthedocs.io/en/latest/api/)、[HTTPX API](https://www.python-httpx.org/api/) 和 [HTTPX 兼容性说明](https://www.python-httpx.org/compatibility/)。上表最后一列是本项目的设计选择，不表示完整兼容其中任一库。

第一版覆盖同步 HTTP/HTTPS、七个常用方法、查询参数、请求头、字节/表单/JSON 请求体、Basic/Bearer 认证、Cookie 会话、超时、重定向、响应解析与流式下载。`AsyncClient`、HTTP/2、multipart 文件上传、流式上传、代理、自动重试、hooks 和可插拔 transport 放到后续版本；不提前加入占位接口。

## 2. 顶层调用

包名使用 `req`，项目名保持 `req.mojo`。

```mojo
import req

var response = req.get("https://example.com")
response.raise_for_status()
print(response.status_code)
print(response.text())
```

统一入口采用明确的关键字参数：

```mojo
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
    timeout: Timeout = Timeout(5.0),
    follow_redirects: Bool = False,
    verify: Bool = True,
) raises HTTPError -> Response

def stream(method: String, url: String, *, ...) raises HTTPError -> Response
```

`stream()` 接受与 `request()` 相同的关键字参数，只改变响应体的读取方式。每次顶层调用使用独立临时客户端；普通请求完成后关闭，流式请求由返回的 `Response` 持有并在关闭时释放。顶层函数之间不共享连接和 Cookie。

提供 `get`、`head`、`post`、`put`、`patch`、`delete`、`options`。`get` 和 `head` 不接受请求体；其余便捷函数可以接受 `content/data/json`。特殊的 GET 请求体通过 `request("GET", ...)` 表达。HEAD 无论如何构造都不发送请求体，响应体始终为空。

`Bytes` 是字节容器类型的别名，目标表示为 `List[UInt8]`，不另建字节框架。第一版 `content=` 只接收字节；文本通过显式 UTF-8 编码传入。后续可用重载补充 `String` 和 `URL` 输入，不使用 Python `Any`。

## 3. Client

```mojo
from req import Client, Headers, QueryParams, Timeout, Auth

with Client(
    base_url="https://api.example.com/v1/",
    headers=Headers({"Accept": "application/json"}),
    auth=Auth.bearer("example-token"),
    timeout=Timeout(10.0),
) as client:
    var response = client.get(
        "users",
        params=QueryParams({"page": "1"}),
    )
    response.raise_for_status()
    var result = response.json()
```

```mojo
struct Client:
    def __init__(
        *,
        base_url: String = "",
        headers: Headers = Headers(),
        params: QueryParams = QueryParams(),
        cookies: CookieJar = CookieJar(),
        auth: Auth = Auth.none(),
        timeout: Timeout = Timeout(5.0),
        follow_redirects: Bool = False,
        max_redirects: Int = 20,
        verify: Bool = True,
        ca_file: Optional[String] = None,
    ) raises HTTPError

    def request(method: String, url: String, *, ...) raises HTTPError -> Response
    def stream(method: String, url: String, *, ...) raises HTTPError -> Response
    def build_request(method: String, url: String, *, ...) raises HTTPError -> Request
    def send(
        request: Request,
        *,
        stream: Bool = False,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response

    def close()
    var cookies: CookieJar
```

`Client` 也提供七个便捷方法，方法与顶层版本的请求体限制一致。`Client.request/stream` 的 `params/headers/content/data/json` 与顶层版本一致；`auth/timeout/follow_redirects` 改为对应的 `Optional` 类型，默认 `None`，表示继承客户端设置。TLS 配置只在构造客户端时指定。

`build_request()` 接收请求内容参数及可选 `auth`，合并客户端配置、解析 URL、编码请求体并生成认证/Cookie 头，但不执行网络 I/O。`send()` 发送已构造的请求，不再次合并客户端的 headers、params、auth 或 cookies；它只补充执行期的超时、重定向和传输所需协议字段。这样签名后的请求不会再次被公共业务配置改写。

客户端复制构造参数，不保留调用方可变容器的隐式别名。`Client` 管理连接和 Cookie 状态，不支持隐式复制；第一版按单线程使用设计，不承诺跨线程共享。

### 配置合并规则

| 配置 | 客户端与单次请求的关系 |
| --- | --- |
| `headers` | 按大小写无关的名称合并；请求级同名值组完整覆盖客户端值组 |
| `params` | URL 自带参数、客户端参数、请求级参数依次合并；后者覆盖同名键的完整值组，保留组内重复值 |
| `auth` | `None` 继承；`Auth.none()` 关闭客户端认证；显式 Basic/Bearer 覆盖 |
| `timeout` | `None` 继承；显式 `Timeout` 整体覆盖；`Timeout.disabled()` 关闭超时 |
| `follow_redirects` | `None` 继承；显式 `True/False` 覆盖 |
| Cookie | `build_request()` 根据目标 URL 从客户端 CookieJar 生成头；响应更新该 Jar |

空的 `Headers` 或 `QueryParams` 表示没有覆盖项，不清空客户端默认值。需要删除默认请求头或查询参数时，先 `build_request()`，再编辑其 `headers` 或 `url`，最后 `send()`。配置合并方式参考 [HTTPX Clients](https://www.python-httpx.org/advanced/clients/)，同名多值的覆盖规则由本草案明确规定。

`base_url` 使用 [RFC 3986 相对引用解析规则](https://www.rfc-editor.org/rfc/rfc3986#section-5)：`https://api.example.com/v1/` 加 `users` 得到 `/v1/users`，加 `/users` 得到 `/users`。不自动改写基址末尾的斜杠。绝对 URL 使用自身地址；相对 URL 没有基址则报 `InvalidURL`。客户端默认认证绑定到基址的 origin；指定其他 origin 的绝对 URL 时不自动附加该认证，需要请求级显式授权。无基址的客户端认证作用于调用方显式提供的初始 URL。

### 生命周期

`with Client(...)` 退出时调用 `close()`；显式 `close()` 可重复调用。关闭后不能再次发送请求或重新进入上下文，报 `ClientClosed`。

普通响应完全拥有缓存字节，可以在客户端关闭后继续解析。流式响应持有传输资源；显式关闭客户端会关闭其活动流，随后读取报 `StreamClosed`。内部句柄保证客户端先关闭、响应后关闭不会重复释放。`Response` 同样不隐式复制。Mojo 可在最后一次使用后提前析构客户端，因此析构只释放客户端的连接池引用，活动响应继续持有连接池；需要取消活动流时使用 `close()` 或上下文退出。

Mojo 的 `with` 绑定返回受 origin 约束的借用视图。临时客户端使用 `with Client(...) as client`；已有客户端使用 `with owner.context() as client`。绑定中的 CookieJar 通过 `client.cookies()` 访问，所有者的字段仍是 `owner.cookies`。临时响应可直接使用 `with client.stream(...) as response`；已有响应使用显式 `close()`。

## 4. Request 与 Response

### Request

```mojo
struct Request:
    def __init__(
        method: String,
        url: String,
        *,
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
    ) raises HTTPError

    var method: String
    var url: URL
    var headers: Headers
    var content: Optional[Bytes]
```

手工构造 `Request` 要求绝对 HTTP/HTTPS URL，不继承任何客户端业务配置。方法名校验为合法 token，常用方法规范为大写；扩展方法保留调用方的大小写。`content=None` 与 `content=Bytes()` 分别保留无请求体与显式空请求体。`send()` 再次校验请求，计算真实字节长度；调用方提供的 `Content-Length` 不匹配则报错，不发送有歧义的消息。第一版拒绝手工设置 `Transfer-Encoding`。

`content/data/json` 在高级入口中互斥，同时提供多个时报 `InvalidRequest`，在联网前失败。空字节与空表单仍属于显式请求体。`json=None` 表示没有 JSON 请求体，发送 JSON null 使用 `JSONValue.null()`。

表单自动设置 `application/x-www-form-urlencoded`，JSON 自动设置 `application/json`；显式 `Content-Type` 优先。表单使用 UTF-8 编码，空格编码为 `+`；URL 查询参数使用 UTF-8 百分号编码，空格为 `%20`。两者都保留重复键。JSON 值类型复用选定 JSON 库，由 HTTP 层负责序列化入口，不扩展为任意对象反射框架。

### Response

```mojo
struct Response:
    var status_code: Int
    var reason_phrase: String
    var http_version: String
    var url: URL
    var headers: Headers
    var request: Request

    def content() raises HTTPError -> Bytes
    def text(*, encoding: Optional[String] = None) raises HTTPError -> String
    def json() raises HTTPError -> JSONValue
    def is_success() -> Bool
    def is_redirect() -> Bool
    def raise_for_status() raises HTTPError
    def read() raises HTTPError -> Bytes
    def read_chunk(max_bytes: Int = 65536) raises HTTPError -> Optional[Bytes]
    def close()
    def is_closed() -> Bool
```

响应元数据由库提供，调用方应按只读使用；Mojo 的公开 `var` 字段未在语言层限制修改。`url` 和 `request` 对应最终一次请求。第一版不提供完整重定向 `history` 或耗时指标，避免过早固定其存储和计时含义。

普通请求返回前读完响应体并释放连接租约。`content/text/json` 只操作缓存，不隐式联网。这里采用 `text()` 和 `content()` 方法，明确它们是可能失败或复制数据的操作；第一版返回拥有所有权的值，不暴露悬垂的字节视图。

普通和流式读取都移除 HTTP 传输分帧，并增量解码 gzip/deflate Content-Encoding；返回值是解压后的字节。自动生成的 Accept-Encoding 只声明这两种能力，未知内容编码报 `DecodeError`。响应 headers 保留服务器原值，因此 Content-Length 可能是压缩后的长度，不等于缓存字节数。Brotli/zstd 和原始压缩字节读取留到后续版本。

`text()` 默认按 Content-Type 的 charset 解码，没有 charset 时使用 UTF-8；第一版至少支持 UTF-8、ASCII、ISO-8859-1。非法字节或不支持的字符集报 `DecodeError`，不自动探测或静默替换。`json()` 按 UTF-8 JSON 解析，不要求 Content-Type 必须是 JSON；无效 JSON 或空响应体（包括 204）报 `JSONDecodeError`。

`is_success()` 仅表示 `200 <= status_code < 300`。`is_redirect()` 表示状态码属于 301/302/303/307/308 且有 Location。4xx/5xx 响应正常返回；只有显式调用 `raise_for_status()` 才报 `HTTPStatusError`。需要严格 2xx 时由调用方检查 `is_success()`。

## 5. 流式读取

```mojo
with req.stream("GET", "https://example.com/archive.tar") as response:
    response.raise_for_status()
    while True:
        var chunk = response.read_chunk(65536)
        if not chunk:
            break
        # Write chunk.value() to the destination file.
```

`stream()` 调用完成时已收到最终响应头，响应体尚未完整缓存。读取有两条互斥路径：

- `read()`：从尚未消费的流读完并缓存，然后允许反复调用 `content/text/json/read`。
- `read_chunk()`：每次返回不超过 `max_bytes` 的非空数据块，EOF 返回 `None`；不累计缓存。进入该路径后，`read/content/text/json` 报 `StreamConsumed`，防止把剩余数据误认为完整响应。

流尚未缓存时直接调用 `content/text/json` 报 `StreamNotRead`。`max_bytes` 必须大于零。完整消费后释放连接租约；提前关闭则放弃未读数据并关闭该连接，不能将未读完的 HTTP/1.1 连接放回池中。读取错误关闭活动连接并传播 `HTTPError`，不得伪装成 EOF。

`close()` 幂等且不传播清理错误，上下文退出不掩盖原始请求或读取错误；析构提供兜底释放。资源关闭后 `is_closed()` 为真，已经缓存的内容仍可访问；未缓存的关闭流报 `StreamClosed`。

Requests 的流式使用也要求消费响应或关闭响应后才能释放连接，见 [Requests Advanced Usage](https://requests.readthedocs.io/en/latest/user/advanced/#body-content-workflow)。第一版先定义可显式报错的 `read_chunk()`；`iter_bytes/iter_lines` 待确认目标编译器的迭代错误契约后再加入，依据见 [Mojo Iterator](https://mojolang.org/docs/std/iter/Iterator/)。

## 6. 辅助类型

| 类型 | 最小公共能力 | 关键约定 |
| --- | --- | --- |
| `URL` | 构造、`scheme/host/port/path/query`、`query_params()`、`with_query(params)`、转字符串 | 不可变值；HTTP/HTTPS、IPv4/IPv6、有效百分号编码；fragment 不发送；第一版 Unicode 域名需调用方先转为 IDNA ASCII |
| `Headers` | Dict 或二元组列表构造；`get/get_all/set/add/remove/items` | 名称大小写无关，保留重复值；`get` 返回第一个值的 Optional，`get_all` 返回所有值；不拼接 Set-Cookie |
| `QueryParams` | Dict 或二元组列表构造；`get/get_all/set/add/remove/items` | 名称大小写敏感，保留重复值和顺序；输入值是 String，数值显式转换 |
| `CookieJar` | `set/get/delete/clear` | 按 domain/path/secure/expiry/host-only 匹配；同名不同作用域的 Cookie 不覆盖彼此 |
| `Timeout` | `Timeout(seconds)`、各阶段关键字构造、`disabled()` | 单位为秒；connect/read/write 分开；值必须为有限正数或显式禁用 |
| `Auth` | `none()`、`basic(username, password)`、`bearer(token)` | 封闭的认证值类型，第一版不提供认证插件 trait |
| `JSONValue` | JSON 对象、数组、字符串、数字、布尔、null 的值类型 | JSON 库的公共集成点，不使用 PythonObject 或 Any |

`Headers/QueryParams` 的 `set` 替换同名全部值，`add` 追加一个值，`remove` 删除同名全部值；`items` 保留每一项而非折叠为 Dict。输入是未编码值，输出时编码一次。请求头名称必须是合法 token，值拒绝 CR/LF。

CookieJar 手工 `set/get/delete` 要求显式 `domain`，`path` 默认 `/`；`set` 可指定 `secure` 和到期时间。来自 Set-Cookie 的 host-only 属性由响应 origin 决定。第一版每次请求的临时 Cookie 用显式请求头表达：显式 `Cookie` 头覆盖自动生成值，不做两种文本的隐式拼接。

当前 CookieJar 不包含公共后缀数据库，Expires 支持 IMF-fixdate；不承诺完整浏览器 Cookie 兼容性。`build_request()` 后手工编辑的 Cookie 头在同 origin 重定向时仍视为显式值；自动生成的 Cookie 按重定向目标重新选择。

显式 `Authorization` 头优先于 `Auth`；自动生成认证仅补充缺失头。重定向跨 origin 时移除 Authorization、Proxy-Authorization 和显式 Cookie，不重新附加初始认证；CookieJar 按新 URL 重新选取 Cookie。HTTPS 到 HTTP 的自动降级重定向报 `UnsafeRedirect`。

## 7. 默认行为与错误

超时默认 `Timeout(5.0)`，分别限制连接建立（含 DNS/TLS）、每次读取和每次写入等待，不等于整个请求必须在 5 秒内结束。`Timeout(connect=3.0, read=30.0, write=10.0)` 表示分阶段配置；关键字构造中省略的字段默认 5 秒，单个字段 `None` 表示禁用该阶段。`Timeout.disabled()` 将三个字段全部禁用。第一版不提供总时限、连接池等待超时或 `Limits`。阶段模型参考 [HTTPX Timeouts](https://www.python-httpx.org/advanced/timeouts/)。

TLS 默认验证证书链与主机名，使用系统信任来源；`ca_file` 显式替换信任来源。`verify=False` 关闭验证，与 `ca_file` 同时提供时报 `InvalidRequest`。第一版配置来自显式参数，不自动读取环境代理、环境 CA 或 netrc。

启用重定向时，默认最多跟随 20 次。303 将非 HEAD 改为 GET；301/302 将 POST 改为 GET，其余方法保持；307/308 保持方法与请求体。改为 GET 时清除请求体及对应实体头。无 Location 的响应直接返回；非法 Location 报 `InvalidURL`；超过跳数报 `TooManyRedirects`。

不自动重试，避免无声重复 POST 等请求。普通请求与流式请求都不将 HTTP 错误状态直接转换为传输失败。

Mojo 使用 struct 与 typed raises 表达结构化错误，见 [Mojo Errors](https://mojolang.org/docs/manual/errors/)。第一版使用一个可捕获的 `HTTPError`，以 `kind` 区分原因，避免照搬 Python 异常继承树：

```mojo
struct HTTPError:
    var kind: ErrorKind
    var message: String
    var method: Optional[String]
    var url: Optional[String]
    var status_code: Optional[Int]
```

`ErrorKind` 是命名枚举值，最小集合如下；错误类别参考 [HTTPX Exceptions](https://www.python-httpx.org/exceptions/)，组织方式为 Mojo 设计。

| 类别 | kind |
| --- | --- |
| 输入 | `InvalidURL`、`InvalidRequest` |
| 网络 | `ConnectError`、`ReadError`、`WriteError`、`TLSError`、`ProtocolError` |
| 超时 | `ConnectTimeout`、`ReadTimeout`、`WriteTimeout` |
| 重定向 | `TooManyRedirects`、`UnsafeRedirect` |
| 响应 | `HTTPStatusError`、`DecodeError`、`JSONDecodeError` |
| 生命周期 | `ClientClosed`、`StreamClosed`、`StreamNotRead`、`StreamConsumed` |

`HTTPStatusError` 填写状态码；响应体保留在调用方已有的 Response 中，错误对象不递归持有它。错误 URL 去除 userinfo，错误信息不自动包含认证头、Cookie 或正文。构造前错误允许 method/url 缺省。HTTP 层将后端和 JSON 库错误映射为此公共类型，不要求调用方识别后端私有错误。

## 8. 实现时的契约检查

实现阶段用本地可控 HTTP 服务验证以下契约，不依赖公网服务的状态：

1. 顶层调用隔离会话，Client 复用连接并按作用域持久化 Cookie。
2. 同名参数组覆盖后仍保留重复值；Headers 大小写无关且 Set-Cookie 不折叠。
3. 未提供请求体、空请求体、JSON null 可区分；互斥参数、错误长度和非法请求头在联网前失败。
4. 基址尾斜杠与前导斜杠解析符合示例；跨 origin 和降级重定向符合认证约定。
5. 连接/读/写超时可区分；默认不跟随重定向；关闭后无法再次发送。
6. 流式 EOF 与读取错误不同；提前关闭释放连接；部分消费后无法误解析完整 JSON。
7. 204、无效 UTF-8、无效 JSON、3xx、4xx、5xx 分别符合解析和状态检查约定；gzip/deflate 的普通与流式解码结果一致。

单测使用本地 HTTP/TLS 服务，按模块组织并由 Mojo `TestSuite` 自动发现 `test_` 函数。测试入口自动收集模块，只编译一个位于项目根目录的临时二进制，运行后删除。当前已在 macOS ARM64 验证；Linux x86-64 的 Pixi 依赖已锁定，执行验证仍待补充。完整包另执行 `mojo precompile --Werror` 检查，避免只依赖单测实例化路径。
