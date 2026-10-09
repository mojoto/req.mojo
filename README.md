# req.mojo

An HTTPX-inspired HTTP client for Mojo, with the familiar convenience API of
Python Requests and native Mojo types.

Development targets **Mojo 1.1.0**. The implementation is being built in tested,
incremental features; see the [core API design](docs/core-api.md) for the contract.

## Development

Install [uv](https://docs.astral.sh/uv/getting-started/installation/), then run:

```sh
make install
make test
make build
```

The package layout follows HTTPX: `req/_api.mojo`, `_client.mojo`, `_models.mojo`,
`_config.mojo`, `_auth.mojo`, `_urls.mojo`, and `_transports/`. Tests are organized
by the same model and client responsibilities.
