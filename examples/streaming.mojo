"""Count downloaded bytes without buffering the complete response."""

from std.sys import argv
from req import stream


def main() raises:
    var args = argv()
    if len(args) != 2:
        raise Error("Usage: streaming <HTTP download URL>")
    with stream("GET", String(args[1])) as response:
        response.raise_for_status()
        var total = 0
        while True:
            var chunk = response.read_chunk(65536)
            if not chunk:
                break
            total += len(chunk.value())
        print(total)
