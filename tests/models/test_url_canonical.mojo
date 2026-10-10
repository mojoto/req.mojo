"""URL canonical tests."""
from .url_cases import canonical_url_cases, rejected_url_cases
from req import ErrorKind, URL
from std.testing import assert_equal, assert_true


def test_canonical_absolute_urls() raises:
    for scenario in canonical_url_cases():
        var url = URL(scenario[1])
        assert_equal(url.scheme(), scenario[2], scenario[0])
        assert_equal(url.host(), scenario[3], scenario[0])
        assert_equal(url.port(), scenario[4], scenario[0])
        assert_equal(url.path(), scenario[5], scenario[0])
        assert_equal(url.query(), scenario[6], scenario[0])
        assert_true("#" not in String(url), scenario[0])


def test_rejected_canonical_urls() raises:
    for scenario in rejected_url_cases():
        var caught = False
        try:
            _ = URL(scenario[1])
        except error:
            assert_equal(error.kind, ErrorKind.InvalidURL, scenario[0])
            caught = True
        assert_true(caught, scenario[0] + ": " + scenario[1])
