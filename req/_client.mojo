"""Persistent synchronous HTTP clients and request policy."""

from std.memory import Pointer
from std.origin import Origin
from ._models import Request, Response, Headers
from ._urls import URL, QueryParams
from ._types import Bytes
from ._json import JSONValue
from ._auth import Auth
from ._cookies import CookieJar
from ._config import Timeout, Limits
from ._body import RequestBody
from ._multipart import UploadFile, encode_multipart, multipart_boundary
from ._proxy import environment_proxy, environment_no_proxy
from std.os import getenv
from std.ffi import c_int
from ._content import encode_body
from ._exceptions import HTTPError, ErrorKind
from ._transports.default import (
    CurlStream,
    Pool,
    new_pool,
    close_pool,
    release_pool,
)


struct Client(Movable):
    var cookies: CookieJar
    var _base_url: Optional[URL]
    var _headers: Headers
    var _params: QueryParams
    var _auth: Auth
    var _timeout: Timeout
    var _follow_redirects: Bool
    var _max_redirects: Int
    var _verify: Bool
    var _ca_file: Optional[String]
    var _pool: Pool
    var _proxy: Optional[String]
    var _trust_env: Bool
    var _ca_path: String

    def __init__(
        out self,
        *,
        base_url: String = "",
        headers: Headers = Headers(),
        params: QueryParams = QueryParams(),
        cookies: CookieJar = CookieJar(),
        auth: Auth = Auth.none(),
        timeout: Timeout = Timeout(),
        follow_redirects: Bool = False,
        max_redirects: Int = 20,
        verify: Bool = True,
        ca_file: Optional[String] = None,
        proxy: Optional[String] = None,
        trust_env: Bool = False,
        limits: Limits = Limits(),
        http1: Bool = True,
        http2: Bool = False,
    ) raises HTTPError:
        self._pool = None
        self.cookies = cookies
        self._base_url = URL(base_url) if base_url else None
        self._headers = headers
        self._params = params
        self._auth = auth
        self._timeout = timeout
        self._follow_redirects = follow_redirects
        self._max_redirects = max_redirects
        self._verify = verify
        self._ca_file = ca_file
        self._proxy = proxy
        self._trust_env = trust_env
        self._ca_path = String()
        if trust_env and not ca_file:
            var file = getenv("SSL_CERT_FILE")
            if file:
                self._ca_file = file
            self._ca_path = getenv("SSL_CERT_DIR")
        timeout.validate()
        if max_redirects < 0 or (not verify and ca_file):
            raise HTTPError(
                ErrorKind.InvalidRequest,
                "Invalid redirect limit or TLS configuration",
            )
        self._pool = new_pool(limits, http1=http1, http2=http2)
        if proxy:
            self._validate_proxy(proxy.value())

    def __deinit__(deinit self):
        # Mojo may destroy an owner after its last use. Active responses retain
        # the pool; explicit close() and context exit cancel those responses.
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

    def _ensure_open(self) raises HTTPError:
        if self.is_closed():
            raise HTTPError(ErrorKind.ClientClosed, "HTTP client is closed")

    def build_request(
        self,
        method: String,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
    ) raises HTTPError -> Request:
        self._ensure_open()
        var target = self._base_url.value().resolve(
            url
        ) if self._base_url else URL(url)
        if len(self._params) or len(params):
            var merged = target.query_params()
            merged.merge(self._params)
            merged.merge(params)
            target = target.with_query(merged)
        var merged_headers = self._headers
        merged_headers.merge(headers)
        var raw_body: Optional[Bytes] = None
        var upload = body
        if files:
            if content or json or body:
                raise HTTPError(
                    ErrorKind.InvalidRequest,
                    "files cannot be combined with content, json or body",
                )
            var encoded = encode_multipart(
                data.value() if data else QueryParams(),
                files,
                multipart_boundary(merged_headers.get("Content-Type")),
            )
            upload = encoded[0]
            if "Content-Type" not in merged_headers:
                merged_headers.set(
                    "Content-Type",
                    "multipart/form-data; boundary=" + encoded[1],
                )
        elif body:
            if content or data or json:
                raise HTTPError(
                    ErrorKind.InvalidRequest,
                    "body cannot be combined with content, data or json",
                )
        else:
            raw_body = encode_body(
                merged_headers, content=content, data=data, json=json
            )
        var cookie_from_jar: Optional[String] = None
        if auth:
            auth.value().apply(merged_headers)
        elif (
            not self._base_url
            or target.origin() == self._base_url.value().origin()
        ):
            self._auth.apply(merged_headers)
        if "Cookie" not in merged_headers:
            var cookie = self.cookies.header(target)
            if cookie:
                merged_headers.set("Cookie", cookie.value())
                cookie_from_jar = cookie
        var request = Request(
            method,
            _url=target^,
            _headers=merged_headers^,
            _content=raw_body^,
            _body=upload,
        )
        request._cookie_from_jar = cookie_from_jar
        return request^

    def send(
        mut self,
        request: Request,
        *,
        stream: Bool = False,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._send_owned(
            request,
            stream=stream,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def _send_owned(
        mut self,
        var current: Request,
        *,
        stream: Bool = False,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        self._ensure_open()
        var effective_timeout = timeout.value() if timeout else self._timeout
        effective_timeout.validate()
        var follow = (
            follow_redirects.value() if follow_redirects else self._follow_redirects
        )
        var redirects = 0
        while True:
            current.validate()
            var headers = String()
            for pair in current.headers.items():
                headers += (
                    pair[0] + (";" if not pair[1] else ": " + pair[1]) + "\n"
                )
            var proxy = self._proxy.value() if self._proxy else (
                environment_proxy(
                    current.url.scheme()
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
                current.method,
                String(current.url),
                headers,
                current.content,
                effective_timeout,
                self._verify,
                self._ca_file,
                body=current.body,
                proxy=proxy,
                no_proxy=no_proxy,
                ca_path=self._ca_path,
            )
            var response = Response.from_stream(source^, current)
            self.cookies.extract(response.headers, current.url)
            if not follow or not response.is_redirect():
                if not stream:
                    response._read_content()
                return response^
            if redirects >= self._max_redirects:
                raise HTTPError(
                    ErrorKind.TooManyRedirects,
                    "Redirect limit exceeded",
                    method=current.method,
                    url=String(current.url),
                )
            var target = current.url.resolve(response.headers["Location"])
            if current.url.scheme() == "https" and target.scheme() == "http":
                raise HTTPError(
                    ErrorKind.UnsafeRedirect,
                    "HTTPS redirect would downgrade to HTTP",
                    method=current.method,
                    url=String(current.url),
                )
            var method = current.method
            var redirected_headers = current.headers
            var body: Optional[Bytes] = None
            var upload = current.body
            if current.content:
                body = current.content.value().copy()
            if (response.status_code == 303 and method != "HEAD") or (
                response.status_code in [301, 302] and method == "POST"
            ):
                method = "GET"
                body = None
                upload = None
                for name in [
                    "Content-Length",
                    "Content-Type",
                    "Content-Encoding",
                ]:
                    redirected_headers.remove(name)
            if target.origin() != current.url.origin():
                for name in [
                    "Authorization",
                    "Proxy-Authorization",
                    "Cookie",
                    "Host",
                ]:
                    redirected_headers.remove(name)
            # Select session cookies for the new URL; explicit same-origin Cookie wins.
            var cookie_from_jar: Optional[String] = None
            if (
                (
                    current._cookie_from_jar
                    and current.headers.get("Cookie")
                    == current._cookie_from_jar
                )
                or "Cookie" not in current.headers
                or target.origin() != current.url.origin()
            ):
                redirected_headers.remove("Cookie")
                var cookie = self.cookies.header(target)
                if cookie:
                    redirected_headers.set("Cookie", cookie.value())
                    cookie_from_jar = cookie
            response.close()
            current = Request(
                method,
                _url=target^,
                _headers=redirected_headers^,
                _content=body^,
                _body=upload,
            )
            current._cookie_from_jar = cookie_from_jar
            redirects += 1

    def request(
        mut self,
        method: String,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        var request = self.build_request(
            method,
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
        )
        return self._send_owned(
            request^, timeout=timeout, follow_redirects=follow_redirects
        )

    def stream(
        mut self,
        method: String,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        var request = self.build_request(
            method,
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
        )
        return self._send_owned(
            request^,
            stream=True,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def get(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self.request(
            "GET",
            url,
            params=params,
            headers=headers,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def head(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self.request(
            "HEAD",
            url,
            params=params,
            headers=headers,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def post(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self.request(
            "POST",
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def put(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self.request(
            "PUT",
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def patch(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self.request(
            "PATCH",
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def delete(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self.request(
            "DELETE",
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def options(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self.request(
            "OPTIONS",
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def __enter__(mut self) raises HTTPError -> ClientContext[origin_of(self)]:
        self._ensure_open()
        return ClientContext[origin_of(self)](Pointer(to=self))

    def context(mut self) raises HTTPError -> ClientContext[origin_of(self)]:
        return self.__enter__()

    def __exit__(mut self):
        self.close()


@fieldwise_init
struct ClientContext[origin: Origin[mut=True]](ImplicitlyCopyable):
    """A borrowed context view preserving the client's ownership and state."""

    var _client: Pointer[Client, Self.origin]

    def __enter__(self) raises HTTPError -> Self:
        self._client[]._ensure_open()
        return self

    def __exit__(mut self):
        self.close()

    def close(mut self):
        self._client[].close()

    def is_closed(self) -> Bool:
        return self._client[].is_closed()

    def cookies(mut self) -> ref[origin_of(self._client[].cookies)] CookieJar:
        return self._client[].cookies

    def request(
        mut self,
        method: String,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].request(
            method,
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def stream(
        mut self,
        method: String,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].stream(
            method,
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def get(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].get(
            url,
            params=params,
            headers=headers,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def head(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].head(
            url,
            params=params,
            headers=headers,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def post(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].post(
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def put(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].put(
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def patch(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].patch(
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def delete(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].delete(
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def options(
        mut self,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].options(
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )

    def build_request(
        self,
        method: String,
        url: String,
        *,
        params: QueryParams = QueryParams(),
        headers: Headers = Headers(),
        content: Optional[Bytes] = None,
        body: Optional[RequestBody] = None,
        files: List[UploadFile] = List[UploadFile](),
        data: Optional[QueryParams] = None,
        json: Optional[JSONValue] = None,
        auth: Optional[Auth] = None,
    ) raises HTTPError -> Request:
        return self._client[].build_request(
            method,
            url,
            params=params,
            headers=headers,
            content=content,
            body=body,
            files=files,
            data=data,
            json=json,
            auth=auth,
        )

    def send(
        mut self,
        request: Request,
        *,
        stream: Bool = False,
        timeout: Optional[Timeout] = None,
        follow_redirects: Optional[Bool] = None,
    ) raises HTTPError -> Response:
        return self._client[].send(
            request,
            stream=stream,
            timeout=timeout,
            follow_redirects=follow_redirects,
        )
