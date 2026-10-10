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
Req 0.1.0 uses Mojo **1.1.0**. Pixi installs the matching compiler, libcurl,
and zlib, together with Req's precompiled module, CPU JSON modules, and native
shared library. Req loads the native transport from the active Pixi environment
automatically; no C build or extra linker flags are needed.

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

Run the example:

```sh
pixi run mojo main.mojo
```

Or compile it and run the binary inside the Pixi environment:

```sh
pixi run mojo build main.mojo -o main
pixi run ./main
```

For source builds and contributor dependencies, see [development](./development.md).

External examples require network access. The project's tests use local fixtures.
Continue with [requests](./requests.md) or [persistent clients](./clients.md).
