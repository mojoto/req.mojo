---
title: Getting Started
---

# Getting started

Install Req and send your first HTTP request from Mojo.

## Requirements

Use Mojo **1.1.0**, [Pixi](https://pixi.sh), a C compiler, and libcurl **7.85+**
with TLS support, and zlib. On macOS install the Command Line Tools
(`xcode-select --install`). On Debian/Ubuntu install
`build-essential libcurl4-openssl-dev zlib1g-dev openssl`.

## Build from source

```sh
git clone https://github.com/mojoto/req.mojo.git
cd req.mojo
pixi install
make build
```

`make build` creates `build/libreq_curl.a` and `build/req.mojoc`. The Pixi
manifest pins the compiler and native JSON dependency. Precompiled `.mojoc`
files require a compatible compiler; use the project's pinned version.

## Send a request

Save this as `main.mojo` in the repository root:

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

Run it with both the native bridge and libcurl linked:

```sh
pixi run mojo run -I . \
  -Xlinker build/libreq_curl.a -Xlinker -lcurl -Xlinker -lz main.mojo
```

`-I .` imports the source package. For a consumer using the precompiled package,
add its directory to the import path and link the native bridge and libcurl as
well. Importing `req` alone does not link the C transport.

External examples require network access. The project's tests use local fixtures.
Continue with [requests](./requests.md) or [persistent clients](./clients.md).
