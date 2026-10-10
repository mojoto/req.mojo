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

需要 [Pixi](https://pixi.sh)、C 编译器、支持 TLS 的 libcurl 7.85+ 和 zlib。
macOS 请安装 Command Line Tools；
Debian/Ubuntu 请安装 `build-essential libcurl4-openssl-dev zlib1g-dev openssl`。

```bash
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

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

运行：

```bash
pixi run mojo run -I . \
  -Xlinker build/libreq_curl.a -Xlinker -lcurl -Xlinker -lz main.mojo
```

更多示例和包集成方式见[快速开始](https://mojoto.github.io/req.mojo/zh-Hans/docs/getting-started)。

## 开发

```bash
make test    # 运行测试
make format  # 格式化代码
make build   # 构建包
```

更多命令和文档开发说明见[开发指南](https://mojoto.github.io/req.mojo/zh-Hans/docs/development)。

Req 使用 [MIT 许可证](LICENSE)。
