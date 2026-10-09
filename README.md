# req.mojo

An HTTPX-inspired HTTP client for Mojo, with the familiar convenience API of
Python Requests and native Mojo types.

Development targets **Mojo 1.1.0**. The implementation is being built in tested,
incremental features; see the [core API design](docs/core-api.md) for the contract.

## Development

Install [pixi](https://pixi.sh), then run:

```sh
pixi install
pixi run test
pixi run build
```

The package layout follows HTTPX: `req/_api.mojo`, `_client.mojo`, `_models.mojo`,
`_config.mojo`, `_auth.mojo`, `_urls.mojo`, and `_transports/`. Tests are organized
by the same model and client responsibilities.

JSON is installed as a Pixi Git dependency pinned to `ehsanmok/json` v0.4.1,
following its [installation guide](https://github.com/ehsanmok/json#install).
