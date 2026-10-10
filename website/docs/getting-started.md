---
title: Getting Started
---

# Getting started

Install Req and send your first HTTP request from Mojo.

## Install with Pixi

From a Pixi workspace
[already configured for Mojo](https://docs.modular.com/mojo/manual/install/),
add the official Modular Community channel and install Req:

```sh
pixi workspace channel add --prepend https://repo.prefix.dev/modular-community
pixi add req
```

The community recipe is being submitted for review; these commands become
available once the package is published to the channel.
Req 0.1.0 uses Mojo **1.1.0**. Pixi resolves the matching compiler, libcurl,
and zlib. The package includes precompiled `req.mojoc`, its CPU JSON modules,
and the native bridge `libreq_curl.a`. Modules are installed into the
environment's `lib/mojo`, and the native library into `lib`, so you do not
need to copy source files or build the bridge yourself.

Supported platforms are Linux x86-64, Linux ARM64, and macOS ARM64.

## Send a request

Save this as `main.mojo` in your workspace root:

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

Compile with the native bridge, libcurl, and zlib linked, then run:

```sh
pixi run mojo build \
  -Xlinker .pixi/envs/default/lib/libreq_curl.a \
  -Xlinker -L.pixi/envs/default/lib \
  -Xlinker -rpath -Xlinker "$PWD/.pixi/envs/default/lib" \
  -Xlinker -lcurl -Xlinker -lz main.mojo -o main
./main
```

`mojo run` ignores the static native bridge passed through `-Xlinker`.

The compiler finds the installed Mojo modules through the active environment.
The command above uses Pixi's default environment at `.pixi/envs/default`;
adjust the paths when using a named environment. Importing `req` alone does
not link the C transport. The runtime library path loads libcurl and zlib
from the same environment.

For source builds and contributor dependencies, see [development](./development.md).

External examples require network access. The project's tests use local fixtures.
Continue with [requests](./requests.md) or [persistent clients](./clients.md).
