<p align="center">
  <img src="website/static/img/req-logo.svg" alt="Req.mojo logo" width="96" height="96" />
</p>

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
Req uses Mojo **1.1.0**. Pixi installs the matching compiler, libcurl,
and zlib, together with Req's precompiled module, CPU JSON modules, and native
shared library. Req loads the native transport from the active Pixi environment
automatically; no C build or extra linker flags are needed.

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

Run the example:

```sh
pixi run mojo main.mojo
```

Or compile it and run the binary inside the Pixi environment:

```sh
pixi run mojo build main.mojo -o main
pixi run ./main
```

See the [getting started guide](https://mojoto.github.io/req.mojo/docs/getting-started)
for more examples and package integration.

## Development

```bash
make install-hooks  # Install the pre-commit formatter (once per clone)
make test    # Run tests
make format  # Format code
make build   # Build the package
```

The hook runs `make format` before each commit. If formatting changes files,
review and stage them, then commit again. It does not stage files automatically.

See the [development guide](https://mojoto.github.io/req.mojo/docs/development)
for more commands and documentation setup.

Req is [MIT licensed](LICENSE).
