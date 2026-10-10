---
title: 快速开始
---

# 快速开始

安装 Req，用 Mojo 发起你的第一个 HTTP 请求。

## 通过 Pixi 安装

在[已配置 Mojo 的 Pixi 工作区](https://docs.modular.com/mojo/manual/install/)中，
添加官方 Modular Community 频道并安装 Req：

```sh
pixi workspace channel add --prepend https://repo.prefix.dev/modular-community
pixi add req
```

社区配方正在提交审核；上述命令在包上架后可用。
Req 0.1.0 使用 Mojo **1.1.0**，Pixi 会解析匹配的编译器、libcurl 和 zlib。
包包含预编译的 `req.mojoc`、所需的 CPU JSON 模块，以及原生桥接库
`libreq_curl.a`。模块安装到环境的 `lib/mojo`，原生库安装到 `lib`，
无需复制源码或自行构建桥接库。

支持 Linux x86-64、Linux ARM64 和 macOS ARM64。

## 发起请求

在 Pixi 工作区根目录创建 `main.mojo`：

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

编译时链接原生桥接库、libcurl 和 zlib，然后运行：

```sh
pixi run mojo build \
  -Xlinker .pixi/envs/default/lib/libreq_curl.a \
  -Xlinker -L.pixi/envs/default/lib \
  -Xlinker -rpath -Xlinker "$PWD/.pixi/envs/default/lib" \
  -Xlinker -lcurl -Xlinker -lz main.mojo -o main
./main
```

`mojo run` 会忽略通过 `-Xlinker` 传入的静态桥接库。

编译器从当前环境查找已安装的 Mojo 模块。上述命令使用 Pixi 默认环境
`.pixi/envs/default`；使用具名环境时，请替换对应路径。
仅 `import req` 不会自动链接 C 传输层；运行时库路径确保加载同一环境的
libcurl 和 zlib。

源码构建和开发依赖见[开发指南](./development.md)。

访问外部站点的示例需要网络；项目测试使用本地服务。继续阅读[请求指南](./requests.md)或[持久客户端](./clients.md)。
