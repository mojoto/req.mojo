"""Pinned v0.28.1 scenarios adapted to the native synchronous API."""
from std.testing import assert_equal, assert_true, assert_raises
from req import URL, QueryParams, ErrorKind


def test_basic_url() raises:
    var url = URL("https://www.example.com/")
    assert_equal(url.scheme(), "https")
    assert_equal(url.host(), "www.example.com")
    assert_equal(url.port(), 443)
    assert_equal(url.path(), "/")
    assert_equal(url.query(), "")
    assert_equal(url.origin(), "https://www.example.com")


def test_complete_url() raises:
    var url = URL("https://example.com:123/path/to/somewhere?abc=123#anchor")
    assert_equal(url.scheme(), "https")
    assert_equal(url.host(), "example.com")
    assert_equal(url.port(), 123)
    assert_equal(url.path(), "/path/to/somewhere")
    assert_equal(url.query(), "abc=123")
    assert_equal(
        String(url), "https://example.com:123/path/to/somewhere?abc=123"
    )


def test_empty_query() raises:
    assert_equal(
        String(URL("https://www.example.com/path?")),
        "https://www.example.com/path?",
    )


def test_no_query() raises:
    assert_equal(
        String(URL("https://www.example.com/path")),
        "https://www.example.com/path",
    )


def test_normalized_host() raises:
    assert_equal(String(URL("https://EXAMPLE.com/")), "https://example.com/")


def test_valid_host() raises:
    assert_equal(String(URL("https://example.com/")), "https://example.com/")


def test_ipv4_like_host() raises:
    assert_equal(String(URL("https://023b76x43144/")), "https://023b76x43144/")


def test_default_https_port() raises:
    assert_equal(
        String(URL("https://example.com:443/")), "https://example.com/"
    )


def test_default_http_port() raises:
    assert_equal(String(URL("http://example.com:80/")), "http://example.com/")


def test_explicit_port() raises:
    assert_equal(
        String(URL("https://example.com:123/")), "https://example.com:123/"
    )


def test_escaped_path() raises:
    assert_equal(
        String(URL("https://example.com/ /🌟/")),
        "https://example.com/%20/%F0%9F%8C%9F/",
    )


def test_raw_dot_path() raises:
    assert_equal(
        String(URL("https://example.com/abc/def/../ghi/./jkl")),
        "https://example.com/abc/def/../ghi/./jkl",
    )


def test_raw_leading_dot() raises:
    assert_equal(
        String(URL("https://example.com/../abc")), "https://example.com/../abc"
    )


def test_query_existing_escape() raises:
    assert_equal(
        String(URL("http://webservice?u=phrase%20with%20spaces")),
        "http://webservice/?u=phrase%20with%20spaces",
    )


def test_query_requires_encoding() raises:
    assert_equal(
        String(URL("http://webservice?u=phrase with spaces")),
        "http://webservice/?u=phrase%20with%20spaces",
    )


def test_query_mixed_encoding() raises:
    assert_equal(
        String(URL("http://webservice?u=phrase%20with spaces")),
        "http://webservice/?u=phrase%20with%20spaces",
    )


def test_valid_ipv4() raises:
    assert_equal(String(URL("http://127.0.0.1/")), "http://127.0.0.1/")


def test_ipv6() raises:
    assert_equal(
        String(URL("http://[::ffff:192.168.0.1]/")),
        "http://[::ffff:192.168.0.1]/",
    )


def test_valid_ipv6() raises:
    assert_equal(String(URL("http://[2001:db8::1]/")), "http://[2001:db8::1]/")


def test_resolution_regression_1833() raises:
    assert_equal(
        String(URL("https://example.com/?[]").resolve("/")),
        "https://example.com/",
    )


def test_join() raises:
    var base = URL("http://example.com/path/to/somewhere")
    assert_equal(
        String(base.resolve("http://example.com/")), "http://example.com/"
    )
    assert_equal(
        String(base.resolve("/somewhere-else")),
        "http://example.com/somewhere-else",
    )
    assert_equal(
        String(base.resolve("somewhere-else")),
        "http://example.com/path/to/somewhere-else",
    )
    assert_equal(
        String(base.resolve("../somewhere-else")),
        "http://example.com/path/somewhere-else",
    )


def test_invalid_port_letters() raises:
    var caught = False
    try:
        _ = URL("https://example.com:abc/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_port_out_of_range() raises:
    var caught = False
    try:
        _ = URL("http://example.com:65536/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_port_zero() raises:
    var caught = False
    try:
        _ = URL("http://example.com:0/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_port_empty() raises:
    var caught = False
    try:
        _ = URL("http://example.com:/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_port_negative() raises:
    var caught = False
    try:
        _ = URL("http://example.com:-1/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_port_overflow() raises:
    var caught = False
    try:
        _ = URL("http://example.com:99999999999999999999/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_hostname() raises:
    var caught = False
    try:
        _ = URL("https://😇/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_non_printing_character_in_url() raises:
    var caught = False
    try:
        _ = URL("https://www.example.com/\n")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_ipv6_address() raises:
    var caught = False
    try:
        _ = URL("http://[xyz]/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_unclosed_ipv6_address() raises:
    var caught = False
    try:
        _ = URL("http://[::1")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_ipv6_authority() raises:
    var caught = False
    try:
        _ = URL("http://[::1]bad/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_url_requires_scheme() raises:
    var caught = False
    try:
        _ = URL("://example.com")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_url_requires_authority() raises:
    var caught = False
    try:
        _ = URL("http://")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_url_rejects_userinfo() raises:
    for text in [
        "https://username:password@example.com",
        "https://username%40gmail.com:pa%20ssword@example.com",
        "https://user%20name:p%40ssword@example.com",
        "https://username@gmail.com:pa ssword@example.com",
        "https://user name:p@ssword@example.com",
    ]:
        var caught = False
        try:
            _ = URL(text)
        except error:
            assert_equal(error.kind, ErrorKind.InvalidURL)
            caught = True
        assert_true(caught, text)


def test_url_rejects_spaces_in_host() raises:
    var caught = False
    try:
        _ = URL("https://exam le.com/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_incomplete_percent_escape() raises:
    var caught = False
    try:
        _ = URL("http://example.com/%")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_invalid_percent_escape() raises:
    var caught = False
    try:
        _ = URL("http://example.com/%GG")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_url_rejects_backslash() raises:
    var caught = False
    try:
        _ = URL("http://example.com/\\a")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_url_rejects_null_byte() raises:
    var caught = False
    try:
        _ = URL("http://example.com/\u0000")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_param_with_space() raises:
    var url = URL("http://webservice/").with_query(
        QueryParams({"u": "with spaces"})
    )
    assert_equal(url.query(), "u=with%20spaces")


def test_param_requires_encoding() raises:
    var url = URL("http://webservice/").with_query(QueryParams({"u": "%"}))
    assert_equal(url.query(), "u=%25")


def test_param_with_percent_encoded() raises:
    var url = URL("http://webservice/").with_query(
        QueryParams({"u": "with%20spaces"})
    )
    assert_equal(url.query(), "u=with%2520spaces")


def test_param_with_existing_escape_requires_encoding() raises:
    var url = URL("http://webservice/").with_query(
        QueryParams({"u": "http://example.com?q=foo%2Fa"})
    )
    assert_equal(url.query(), "u=http%3A%2F%2Fexample.com%3Fq%3Dfoo%252Fa")


def test_url_params() raises:
    var url = URL("https://example.com:123/path?b=456").with_query(
        QueryParams("a=123")
    )
    assert_equal(url.query(), "a=123")
    assert_equal(url.query_params()["a"], "123")


def test_url_equality() raises:
    assert_true(
        URL("http://EXAMPLE.com:80/a?b=1") == URL("http://example.com/a?b=1")
    )
    assert_true(URL("http://example.com/a") != URL("http://example.com/b"))
    assert_true(URL("http://example.com/a") != URL("http://example.com/a?"))
    assert_true(
        URL("http://example.com/a?b=1") != URL("http://example.com/a?b=2")
    )


def test_invalid_ipv4() raises:
    var caught = False
    try:
        _ = URL("https://999.999.999.999/")
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_url_too_long() raises:
    var value = String("https://www.example.com/")
    for _ in range(100000):
        value += "x"
    var caught = False
    try:
        _ = URL(value)
    except error:
        assert_equal(error.kind, ErrorKind.InvalidURL)
        caught = True
    assert_true(caught)


def test_raw_query_encoding() raises:
    var url = URL("https://www.example.com/?a=b c&d=e/f")
    assert_equal(url.query(), "a=b%20c&d=e/f")
    url = URL("https://www.example.com/?a=b+c&d=e/f")
    assert_equal(url.query(), "a=b+c&d=e/f")
    url = URL("https://www.example.com/").with_query(
        QueryParams({"a": "b c", "d": "e/f"})
    )
    assert_equal(url.query(), "a=b%20c&d=e%2Ff")


def test_url_join_rfc3986() raises:
    var base = URL("http://example.com/b/c/d;p?q")
    var cases: List[Tuple[String, String]] = [
        ("g", "http://example.com/b/c/g"),
        ("./g", "http://example.com/b/c/g"),
        ("g/", "http://example.com/b/c/g/"),
        ("/g", "http://example.com/g"),
        ("//g", "http://g/"),
        ("?y", "http://example.com/b/c/d;p?y"),
        ("g?y", "http://example.com/b/c/g?y"),
        ("#s", "http://example.com/b/c/d;p?q"),
        ("g#s", "http://example.com/b/c/g"),
        ("g?y#s", "http://example.com/b/c/g?y"),
        (";x", "http://example.com/b/c/;x"),
        ("g;x", "http://example.com/b/c/g;x"),
        ("g;x?y#s", "http://example.com/b/c/g;x?y"),
        ("", "http://example.com/b/c/d;p?q"),
        (".", "http://example.com/b/c/"),
        ("./", "http://example.com/b/c/"),
        ("..", "http://example.com/b/"),
        ("../", "http://example.com/b/"),
        ("../g", "http://example.com/b/g"),
        ("../..", "http://example.com/"),
        ("../../", "http://example.com/"),
        ("../../g", "http://example.com/g"),
        ("../../../g", "http://example.com/g"),
        ("../../../../g", "http://example.com/g"),
        ("/./g", "http://example.com/g"),
        ("/../g", "http://example.com/g"),
        ("g.", "http://example.com/b/c/g."),
        (".g", "http://example.com/b/c/.g"),
        ("g..", "http://example.com/b/c/g.."),
        ("..g", "http://example.com/b/c/..g"),
        ("./../g", "http://example.com/b/g"),
        ("./g/.", "http://example.com/b/c/g/"),
        ("g/./h", "http://example.com/b/c/g/h"),
        ("g/../h", "http://example.com/b/c/h"),
        ("g;x=1/./y", "http://example.com/b/c/g;x=1/y"),
        ("g;x=1/../y", "http://example.com/b/c/y"),
        ("g?y/./x", "http://example.com/b/c/g?y/./x"),
        ("g?y/../x", "http://example.com/b/c/g?y/../x"),
        ("g#s/./x", "http://example.com/b/c/g"),
        ("g#s/../x", "http://example.com/b/c/g"),
    ]
    for scenario in cases:
        assert_equal(String(base.resolve(scenario[0])), scenario[1])


def test_path_query_fragment() raises:
    var cases: List[Tuple[String, String]] = [
        (
            "https://example.com/!$&'()*+,;= abc ABC 123 :/[]@",
            "https://example.com/!$&'()*+,;=%20abc%20ABC%20123%20:/[]@",
        ),
        (
            "https://example.com/!$&'()*+,;=%20abc%20ABC%20123%20:/[]@",
            "https://example.com/!$&'()*+,;=%20abc%20ABC%20123%20:/[]@",
        ),
        ("https://example.com/ %61%62%63", "https://example.com/%20%61%62%63"),
        (
            "https://example.com/?!$&'()*+,;= abc ABC 123 :/[]@?",
            "https://example.com/?!$&'()*+,;=%20abc%20ABC%20123%20:/[]@?",
        ),
        (
            "https://example.com/?!$&%27()*+,;=%20abc%20ABC%20123%20:%2F[]@?",
            "https://example.com/?!$&%27()*+,;=%20abc%20ABC%20123%20:%2F[]@?",
        ),
        (
            "https://example.com/?%20%97%98%99",
            "https://example.com/?%20%97%98%99",
        ),
        (
            "https://example.com/#!$&'()*+,;= abc ABC 123 :/[]@?#",
            "https://example.com/",
        ),
    ]
    for scenario in cases:
        assert_equal(String(URL(scenario[0])), scenario[1])


def test_ipv6_url() raises:
    var url = URL("http://[::ffff:192.168.0.1]:5678/")
    assert_equal(url.host(), "::ffff:192.168.0.1")
    assert_equal(url.port(), 5678)
    assert_equal(url.origin(), "http://[::ffff:192.168.0.1]:5678")


def test_url_length_boundary() raises:
    var value = String("http://example.com/")
    while value.byte_length() < 65536:
        value += "x"
    assert_equal(String(URL(value)).byte_length(), 65536)
    value += "x"
    with assert_raises():
        _ = URL(value)


def test_url_param_mutations() raises:
    var url = URL("http://example.com/path?a=one&a=two&b=keep")
    var params = url.query_params()
    params.set("a", "new")
    assert_equal(
        url.with_query(params).query_params().get_all("a"),
        List[String](["new"]),
    )
    params.add("a", "next")
    assert_equal(
        url.with_query(params).query_params().get_all("a"),
        List[String](["new", "next"]),
    )
    params.remove("a")
    assert_equal(url.with_query(params).query(), "b=keep")
    params.merge(QueryParams("b=override&c=new"))
    assert_equal(url.with_query(params).query_params()["b"], "override")
    assert_equal(url.with_query(params).query_params()["c"], "new")
    assert_equal(url.query(), "a=one&a=two&b=keep")


comptime TEST_FUNCTIONS = __functions_in_module()
