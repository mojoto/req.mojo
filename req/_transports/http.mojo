"""Native HTTP transport configuration and connection ownership."""

from std.ffi import c_int
from std.os import getenv
from .base import BaseTransport
from .default import CurlStream, Pool, new_pool, close_pool, release_pool
from .._config import Timeout, Limits
from .._models import Request, Response
from .._exceptions import HTTPError, ErrorKind
from .._proxy import environment_proxy, environment_no_proxy


struct HTTPTransport(BaseTransport):
    var _pool: Pool
    var _verify: Bool
    var _ca_file: Optional[String]
    var _ca_path: String
    var _proxy: Optional[String]
    var _trust_env: Bool

    def __init__(
        out self,
        *,
        verify: Bool = True,
        ca_file: Optional[String] = None,
        proxy: Optional[String] = None,
        trust_env: Bool = False,
        limits: Limits = Limits(),
        http1: Bool = True,
        http2: Bool = False,
    ) raises HTTPError:
        self._pool = None
        self._verify = verify
        self._ca_file = ca_file
        self._ca_path = String()
        self._proxy = proxy
        self._trust_env = trust_env
        if not verify and ca_file:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Invalid TLS configuration"
            )
        if trust_env and not ca_file:
            var file = getenv("SSL_CERT_FILE")
            if file:
                self._ca_file = file
            self._ca_path = getenv("SSL_CERT_DIR")
        self._pool = new_pool(limits, http1=http1, http2=http2)
        if proxy:
            self._validate_proxy(proxy.value())

    def __deinit__(deinit self):
        # Active responses retain their pools independently of this owner.
        release_pool(self._pool)

    def _validate_proxy(self, var proxy: String) raises HTTPError:
        for byte in proxy.as_bytes():
            if byte <= 32 or byte == 127:
                raise HTTPError(ErrorKind.InvalidRequest, "Invalid proxy URL")
        var result: Int
        try:
            var validate = self._pool.value()[].library.get_function[c_int](
                "req_proxy_validate"
            )
            result = Int(validate(proxy.as_c_string_span().ptr()))
        except:
            raise HTTPError(ErrorKind.ConnectError, "Cannot validate proxy URL")
        if result >= 0:
            raise HTTPError(ErrorKind.InvalidRequest, "Invalid proxy URL")

    def close(mut self):
        close_pool(self._pool)
        release_pool(self._pool)

    def is_closed(self) -> Bool:
        return not Bool(self._pool)

    def handle_request(
        mut self, request: Request, timeout: Timeout = Timeout()
    ) raises HTTPError -> Response:
        if self.is_closed():
            raise HTTPError(ErrorKind.ClientClosed, "Transport is closed")
        request.validate()
        timeout.validate()

        var headers = String()
        for pair in request.headers.items():
            headers += pair[0] + (";" if not pair[1] else ": " + pair[1]) + "\n"
        var proxy = self._proxy.value() if self._proxy else (
            environment_proxy(
                request.url.scheme()
            ) if self._trust_env else String()
        )
        if proxy:
            self._validate_proxy(proxy)
        var no_proxy = (
            environment_no_proxy() if self._trust_env
            and not self._proxy else String()
        )
        var source = CurlStream(
            self._pool,
            request.method,
            String(request.url),
            headers,
            request.content,
            timeout,
            self._verify,
            self._ca_file,
            body=request.body,
            proxy=proxy,
            no_proxy=no_proxy,
            ca_path=self._ca_path,
        )
        return Response.from_stream(source^, request)
