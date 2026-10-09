# req.mojo

A native synchronous HTTP client for Mojo.

```mojo
import req


def main() raises:
    var response = req.get("https://example.com")
    response.raise_for_status()
    print(response.status_code)
    print(response.headers["Content-Type"])
    print(response.text())
```

## Features

- Synchronous HTTP/1.1 and HTTPS with certificate verification.
- Persistent clients with connection reuse and scoped cookies.
- Query parameters, repeated headers, forms, and native JSON.
- Basic and Bearer authentication.
- Separate connect, read, and write timeouts.
- Optional redirects with credentials removed across origins.
- Streaming downloads and incremental gzip/deflate decoding.
- Typed errors and explicit resource ownership.

Requests default to verified TLS, five-second phase timeouts, and no automatic
redirects or retries. HTTP 4xx/5xx responses return normally; call
`raise_for_status()` to raise an error.

## Installation

Requires Mojo 1.1.0, [Pixi](https://pixi.sh), a C compiler, and libcurl 7.85+ with
TLS and gzip support. On macOS, install the Command Line Tools. On Debian/Ubuntu,
install `build-essential libcurl4-openssl-dev openssl`.

```sh
pixi install
pixi run build
```

JSON is installed through Pixi, following
[ehsanmok/json's installation guide](https://github.com/ehsanmok/json#install).

## Streaming

```mojo
import req


def main() raises:
    with req.stream("GET", "https://example.com/archive") as response:
        response.raise_for_status()
        while True:
            var chunk = response.read_chunk(65536)
            if not chunk:
                break
            print(len(chunk.value()))
```

Use `read()` to buffer an untouched stream, or `read_chunk()` to consume it
incrementally. Context exit closes the response. `Client` provides the same
request methods, plus shared settings, cookies, and connection reuse.

## Documentation

See the [core API contract](docs/core-api.md) and the [examples](examples/) for
clients, request bodies, authentication, redirects, errors, and resource ownership.

This version supports synchronous HTTP/1.1. Async, HTTP/2, multipart, proxies,
and automatic retries are outside its scope. Clients are intended for
single-threaded use. Cookie handling has no public-suffix database and supports
IMF-fixdate Expires values. Local validation covers macOS ARM64; Linux x86-64
execution remains unverified.

## Testing

```sh
pixi run test
make test TEST_ARGS="--only test_client_requests_and_reuse"
pixi run format
```

Tests use local HTTP/TLS fixtures. The runner automatically collects test
modules, lets Mojo's `TestSuite` discover their `test_` functions, and builds one
`.req-test-suite` executable in the project root. It removes temporary files
after the run.

req.mojo is [MIT licensed](LICENSE).
