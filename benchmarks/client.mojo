from std.os import getenv
from std.ffi import external_call, c_int, c_long
from req import Client, HTTPError, ErrorKind, Bytes


@export("mojo_worker")
def worker(index: c_long) abi("C") -> c_int:
    try:
        var url = getenv("BENCH_URL")
        var vary_url = getenv("BENCH_VARY_URL") == "1"
        var size = Int(getenv("BENCH_SIZE"))
        var header_count = 0
        var configured = getenv("BENCH_HEADERS")
        if configured:
            header_count = Int(configured)
        var method = String("GET")
        var upload: Optional[Bytes] = None
        var upload_size = getenv("BENCH_UPLOAD_SIZE")
        if upload_size and Int(upload_size) > 0:
            method = "POST"
            upload = Bytes(length=Int(upload_size), fill=120)
        var client = Client()
        for warmup in range(30):
            var warm = client.request(
                method, url + "?request=" + String(warmup), content=upload
            ) if vary_url else client.request(method, url, content=upload)
            if warm.status_code != 200 or len(warm.content()) != size:
                raise HTTPError(
                    ErrorKind.InvalidRequest, "Invalid warmup response"
                )
            for byte in warm.content():
                if byte != 120:
                    raise HTTPError(
                        ErrorKind.InvalidRequest, "Invalid warmup body"
                    )
            if header_count and warm.headers[
                "x-bench-header-name-" + String(header_count - 1)
            ] != String(header_count - 1):
                raise HTTPError(
                    ErrorKind.InvalidRequest, "Invalid warmup response headers"
                )
        var deadline = external_call["bench_wait", UInt64]()
        var count = UInt64(0)
        var errors = UInt64(0)
        var first = String()
        var reused = True
        while external_call["bench_now", UInt64]() < deadline:
            var sampled = count % 16 == 0
            var begin = external_call[
                "bench_now", UInt64
            ]() if sampled else UInt64(0)
            external_call["bench_enter", NoneType]()
            try:
                var response = client.request(
                    method, url + "?request=" + String(count), content=upload
                ) if vary_url else client.request(method, url, content=upload)
                var body = response.content()
                if response.status_code != 200 or len(body) != size:
                    raise HTTPError(
                        ErrorKind.InvalidRequest,
                        "Invalid response status or length",
                    )
                if body[0] != 120 or body[size - 1] != 120:
                    raise HTTPError(
                        ErrorKind.InvalidRequest, "Invalid response body"
                    )
                var connection = response.headers["x-connection-id"]
                if not first:
                    first = connection
                reused = reused and connection == first
            except:
                errors += 1
            external_call["bench_leave", NoneType]()
            if sampled:
                external_call["bench_sample", NoneType](
                    index, external_call["bench_now", UInt64]() - begin
                )
            count += 1
        external_call["bench_finish", NoneType](
            index, count, errors, c_int(reused and Bool(first))
        )
        client.close()
        return 0
    except error:
        print("worker_error", index, error)
        _ = external_call["fflush", c_int](0)
        return 1


def main() raises:
    # Initialize libcurl before worker threads create independent pools.
    var initial = Client()
    initial.close()
    var result = external_call["bench_run", c_int](
        c_long(Int(getenv("BENCH_CONCURRENCY"))),
        c_long(Int(getenv("BENCH_SECONDS"))),
    )
    if result:
        raise Error("Concurrent benchmark failed")
