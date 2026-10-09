"""Run buffered requests against the URL supplied on the command line."""

from std.sys import argv
from req import Client, JSONValue, QueryParams


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("Usage: quickstart <HTTP echo URL>")
    with Client(base_url=String(args[1])) as client:
        var response = client.get("", params=QueryParams({"language": "Mojo"}))
        response.raise_for_status()
        print(response.text())
        var payload = JSONValue.object()
        payload.set("message", JSONValue("Hello from Mojo"))
        var created = client.post("", json=payload)
        created.raise_for_status()
        print(created.json().to_string())
