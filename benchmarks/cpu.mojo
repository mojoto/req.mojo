"""CPU-only header operations; HTTP end-to-end measurements use client.mojo."""

from std.benchmark import black_box, keep
from std.os import getenv
from std.time import perf_counter_ns
from req import Headers, Bytes
from req._utils import is_token, decode_utf8


def main() raises:
    var mode = getenv("BENCH_CPU_MODE")
    var size = Int(getenv("BENCH_CPU_SIZE"))
    var headers = Headers({"Content-Type": "application/octet-stream"})
    for i in range(size):
        headers.add("X-Bench-Header-Name-" + String(i), String(i))
    var queries = [
        "x-bench-header-name-" + String(size - 1),
        "X-BENCH-HEADER-NAME-0",
        "Content-Type",
        "missing",
    ]
    var token = decode_utf8(Bytes(length=size, fill=65))
    var tokens = [token, token + " ", "雪" + token]
    var expected = String(size - 1).byte_length() + 1 + 24
    var operations = 4
    if mode == "token":
        expected = 1
        operations = 3
    var count = 0
    var checksum = 0
    var start = perf_counter_ns()
    while perf_counter_ns() - start < 500_000_000:
        var result = 0
        if mode == "token":
            for text in tokens:
                result += Int(is_token(black_box(text)))
        else:
            for query in queries:
                var value = headers.get(black_box(query))
                if value:
                    result += value.value().byte_length()
        keep(result)
        if result != expected:
            raise Error("Invalid CPU benchmark result")
        checksum += result
        count += 1
    print("RESULT", count * operations, perf_counter_ns() - start, checksum)
