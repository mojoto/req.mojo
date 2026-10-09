"""Convenient isolated requests with response-owned streaming lifetimes."""

from ._client import Client
from ._models import Headers, Response
from ._urls import QueryParams
from ._types import Bytes
from ._json import JSONValue
from ._config import Timeout
from ._auth import Auth
from ._exceptions import HTTPError


def request(
    method: String,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    var client = Client(
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )
    return client.request(
        method,
        url,
        params=params,
        headers=headers,
        content=content,
        data=data,
        json=json,
    )


def stream(
    method: String,
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    var client = Client(
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )
    var response = client.stream(
        method,
        url,
        params=params,
        headers=headers,
        content=content,
        data=data,
        json=json,
    )
    response._stream.value().owns_pool = client._pool
    client._pool = 0
    return response^


def get(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    return request(
        "GET",
        url,
        params=params,
        headers=headers,
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )


def head(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    return request(
        "HEAD",
        url,
        params=params,
        headers=headers,
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )


def post(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    return request(
        "POST",
        url,
        params=params,
        headers=headers,
        content=content,
        data=data,
        json=json,
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )


def put(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    return request(
        "PUT",
        url,
        params=params,
        headers=headers,
        content=content,
        data=data,
        json=json,
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )


def patch(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    return request(
        "PATCH",
        url,
        params=params,
        headers=headers,
        content=content,
        data=data,
        json=json,
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )


def delete(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    return request(
        "DELETE",
        url,
        params=params,
        headers=headers,
        content=content,
        data=data,
        json=json,
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )


def options(
    url: String,
    *,
    params: QueryParams = QueryParams(),
    headers: Headers = Headers(),
    content: Optional[Bytes] = None,
    data: Optional[QueryParams] = None,
    json: Optional[JSONValue] = None,
    auth: Auth = Auth.none(),
    timeout: Timeout = Timeout(),
    follow_redirects: Bool = False,
    verify: Bool = True,
    ca_file: Optional[String] = None,
) raises HTTPError -> Response:
    return request(
        "OPTIONS",
        url,
        params=params,
        headers=headers,
        content=content,
        data=data,
        json=json,
        auth=auth,
        timeout=timeout,
        follow_redirects=follow_redirects,
        verify=verify,
        ca_file=ca_file,
    )
