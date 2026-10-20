---
title: RequestBody 与 UploadFile
---

# RequestBody 与 UploadFile

## RequestBody

通过 `body=` 发送文件，避免先把整个文件读入 Mojo 内存；也可以发送有限的字节块列表。
不能与 `content`、`data`、`json`、`files` 同时使用。

```text
RequestBody.from_file(path: String) raises HTTPError -> RequestBody
RequestBody.from_bytes(content: Bytes) raises HTTPError -> RequestBody
RequestBody.from_chunks(
    chunks: List[Bytes],
    *,
    known_length: Bool = False,
    replayable: Bool = False,
) raises HTTPError -> RequestBody

def content_length(self) raises HTTPError -> Optional[Int]
def close(mut self)
def is_closed(self) -> Bool
```

`from_file` 在构造时打开文件，发送时逐块读取。文件体可重放；修改文件可能导致 `WriteError`。
`from_bytes` 复制字节，生成可重放请求体。
`from_chunks` 在构造时复制列表中的字节，是有限内存数据源，不是回调或无限生成流。
默认长度未知且只能发送一次；`known_length=True` 声明字节长度，
`replayable=True` 允许再次发送。

```mojo
var response = req.post(
    "https://httpbin.org/post",
    body=req.RequestBody.from_file("report.csv"),
)
response.raise_for_status()
```

`content_length()` 对未知长度请求体返回 `None`。
RequestBody 的副本共享原生数据源状态：一次性请求体的别名不能重复发送。
关闭一个包装值会释放该值的引用，已准备的请求仍可保留数据源。

## UploadFile

通过 `files=` 发送 multipart 文件，配合 `data=QueryParams(...)` 添加普通或重复字段。
Req 自动生成 boundary 和 Content-Type；手工指定 Content-Type 时必须包含合法匹配的 multipart boundary。
`files` 不能与 `content`、`json`、`body` 同时使用。

```text
def __init__(
    out self, name: String, path: String, *,
    filename: Optional[String] = None,
    content_type: String = "application/octet-stream",
) raises HTTPError

def __init__(
    out self, name: String, body: RequestBody, *,
    filename: String = "upload",
    content_type: String = "application/octet-stream",
) raises HTTPError

UploadFile.from_bytes(
    name: String, content: Bytes, *,
    filename: String = "upload",
    content_type: String = "application/octet-stream",
) raises HTTPError -> UploadFile
```

`UploadFile(name, path)` 默认使用文件路径的最后一段作为 filename。
公开字段为 `name`、`filename`、`content_type`、`body`。

```mojo
import req


def main() raises:
    var files = List[req.UploadFile]()
    files.append(req.UploadFile.from_bytes(
        "file", req.encode_utf8("hello\n"),
        filename="hello.txt", content_type="text/plain",
    ))
    var fields = req.QueryParams("tag=mojo&tag=http")
    var response = req.post(
        "https://httpbin.org/post", data=fields, files=files,
    )
    response.raise_for_status()
    print(response.status_code)
```

307/308 重定向保留请求体，要求可重放数据源；重放已消费的一次性请求体会抛出 `StreamConsumed`。
改为 GET 的重定向会移除请求体。上传支持 HTTP/1.1 和 HTTP/2。
