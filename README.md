# Req.mojo

A synchronous HTTP client for Mojo.

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

Language: English | [中文](README.zh-CN.md)

> Documentation: https://mojoto.github.io/req.mojo/

## Installation

Requires [Pixi](https://pixi.sh), a C compiler, libcurl 7.85+ with TLS support,
and zlib. Install Command Line Tools on macOS, or
`build-essential libcurl4-openssl-dev zlib1g-dev openssl` on Debian/Ubuntu.

```bash
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

## Usage

Save the following example as `main.mojo` in the repository root:

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

Run:

```bash
pixi run mojo run -I . \
  -Xlinker build/libreq_curl.a -Xlinker -lcurl -Xlinker -lz main.mojo
```

See the [getting started guide](https://mojoto.github.io/req.mojo/docs/getting-started)
for more examples and package integration.

## Development

```bash
make test    # Run tests
make format  # Format code
make build   # Build the package
```

See the [development guide](https://mojoto.github.io/req.mojo/docs/development)
for more commands and documentation setup.

Req is [MIT licensed](LICENSE).
