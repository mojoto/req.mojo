# Req.mojo

面向 Mojo 的同步 HTTP 客户端。

<p align="center">
  <a href="https://github.com/mojoto/req.mojo/actions/workflows/test.yml">
    <img src="https://github.com/mojoto/req.mojo/actions/workflows/test.yml/badge.svg" alt="Test" />
  </a>
  <a href="https://github.com/mojoto/req.mojo/actions/workflows/pages.yml">
    <img src="https://github.com/mojoto/req.mojo/actions/workflows/pages.yml/badge.svg" alt="Documentation" />
  </a>
  <a href="https://github.com/mojoto/req.mojo/releases">
    <img alt="GitHub release" src="https://img.shields.io/github/v/release/mojoto/req.mojo">
  </a>
</p>

语言：[English](README.md) | 中文

> 文档：https://mojoto.github.io/req.mojo/zh-Hans/

## 安装

在[已配置 Mojo 的 Pixi 工作区](https://docs.modular.com/mojo/manual/install/)中，
添加官方 Modular Community 频道并安装 Req：

```bash
pixi workspace channel add --prepend https://repo.prefix.dev/modular-community
pixi add req
```

社区配方正在提交审核；上述命令在包上架后可用。
Req 0.1.0 使用 Mojo **1.1.0**，Pixi 会解析匹配的编译器、libcurl 和 zlib。
包将 `req.mojoc` 和 JSON 模块安装到环境的 `lib/mojo`，
将 `libreq_curl.a` 安装到 `lib`，无需复制源码或自行构建 C 桥接库。

## 用法

将下面的示例保存为项目根目录下的 `main.mojo`：

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

编译时链接已安装的原生桥接库、libcurl 和 zlib，然后运行：

```bash
pixi run mojo build \
  -Xlinker .pixi/envs/default/lib/libreq_curl.a \
  -Xlinker -L.pixi/envs/default/lib \
  -Xlinker -rpath -Xlinker "$PWD/.pixi/envs/default/lib" \
  -Xlinker -lcurl -Xlinker -lz main.mojo -o main
./main
```

`mojo run` 会忽略通过 `-Xlinker` 传入的静态桥接库。

更多示例和包集成方式见[快速开始](https://mojoto.github.io/req.mojo/zh-Hans/docs/getting-started)。

## 开发

```bash
make test    # 运行测试
make format  # 格式化代码
make build   # 构建包
```

更多命令和文档开发说明见[开发指南](https://mojoto.github.io/req.mojo/zh-Hans/docs/development)。

Req 使用 [MIT 许可证](LICENSE)。
