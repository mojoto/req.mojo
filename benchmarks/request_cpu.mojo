from std.benchmark import black_box, keep
from std.os import getenv
from std.time import perf_counter_ns
from req import Client, Bytes

def main() raises:
    var size = Int(getenv("BENCH_UPLOAD_SIZE"))
    var content: Optional[Bytes] = None
    var method = String("GET")
    if size:
        content = Bytes(length=size, fill=120)
        method = "POST"
    var url = String("http://example.com/keep/128")
    var mode = getenv("BENCH_URL_KIND")
    if mode == "long":
        url += String(from_utf8=Span(Bytes(length=512, fill=97)))
    elif mode == "escaped":
        url += "/a%2fb/雪?x=%2f"
    var expected = String(Client().build_request(method, url, content=content).url)
    var client = Client()
    var count = 0
    var checksum = 0
    var start = perf_counter_ns()
    while perf_counter_ns() - start < 500_000_000:
        var request = client.build_request(black_box(method), black_box(url), content=content)
        var result = String(request.url).byte_length()
        if request.content:
            ref body = request.content.value()
            if len(body) != size or body[0] != 120 or body[size - 1] != 120:
                raise Error("Invalid prepared body")
            result += len(body)
        if String(request.url) != expected:
            raise Error("Invalid prepared URL")
        keep(result)
        checksum += result
        count += 1
    print("RESULT", count, perf_counter_ns() - start, checksum)
    client.close()
