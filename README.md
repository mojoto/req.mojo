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

From a Pixi workspace
[already configured for Mojo](https://docs.modular.com/mojo/manual/install/),
add the official Modular Community channel and install Req:

```bash
pixi workspace channel add --prepend https://repo.prefix.dev/modular-community
pixi add req
```

The community recipe is being submitted for review; these commands become
available once the package is published to the channel.
Req 0.1.0 uses Mojo **1.1.0**. Pixi resolves the matching compiler, libcurl,
and zlib. The package installs `req.mojoc` and the JSON modules into the
environment's `lib/mojo`, and `libreq_curl.a` into `lib`, so you do not need
to copy source files or build the C bridge yourself.

## Usage

Save the following example as `main.mojo` in your workspace root:

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

Compile with the installed native bridge, libcurl, and zlib linked, then run:

```bash
pixi run mojo build \
  -Xlinker .pixi/envs/default/lib/libreq_curl.a \
  -Xlinker -L.pixi/envs/default/lib \
  -Xlinker -rpath -Xlinker "$PWD/.pixi/envs/default/lib" \
  -Xlinker -lcurl -Xlinker -lz main.mojo -o main
./main
```

`mojo run` ignores the static native bridge passed through `-Xlinker`.

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
