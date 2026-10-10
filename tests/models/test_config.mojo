"""Config tests."""
from req import Client, Timeout
from std.math import inf, nan
from std.testing import assert_equal, assert_raises, assert_true


def test_timeout_default() raises:
    var timeout = Timeout()
    timeout.validate()
    assert_equal(timeout.connect.value(), Float64(5.0))
    assert_equal(timeout.read.value(), Float64(5.0))
    assert_equal(timeout.write.value(), Float64(5.0))


def test_timeout_single() raises:
    var timeout = Timeout(10.0)
    timeout.validate()
    assert_equal(timeout.connect.value(), Float64(10.0))
    assert_equal(timeout.read.value(), Float64(10.0))
    assert_equal(timeout.write.value(), Float64(10.0))


def test_timeout_all() raises:
    var timeout = Timeout(connect=1.0, read=2.0, write=3.0)
    timeout.validate()
    assert_equal(timeout.connect.value(), Float64(1.0))
    assert_equal(timeout.read.value(), Float64(2.0))
    assert_equal(timeout.write.value(), Float64(3.0))


def test_timeout_disabled() raises:
    var timeout = Timeout.disabled()
    timeout.validate()
    assert_true(not timeout.connect)
    assert_true(not timeout.read)
    assert_true(not timeout.write)


def test_timeout_partial() raises:
    var timeout = Timeout(connect=None, read=2.0, write=None)
    timeout.validate()
    assert_true(not timeout.connect)
    assert_equal(timeout.read.value(), Float64(2.0))
    assert_true(not timeout.write)


def test_timeout_copy() raises:
    var original = Timeout(10.0)
    var copy = original
    copy.read = 2.0
    assert_equal(original.read.value(), Float64(10.0))
    assert_equal(copy.read.value(), Float64(2.0))


def test_timeout_invalid() raises:
    for value in [
        Float64(0),
        Float64(-1),
        inf[DType.float64](),
        -inf[DType.float64](),
        nan[DType.float64](),
    ]:
        with assert_raises():
            _ = Timeout(value)
    var mutated = Timeout()
    mutated.read = -1.0
    with assert_raises():
        mutated.validate()
    with assert_raises():
        _ = Client(timeout=mutated)


def test_timeout_defaults_and_overrides() raises:
    assert_equal(Timeout().read.value(), 5.0)
    assert_equal(Timeout(10.0).write.value(), 10.0)
    var timeout = Timeout(connect=3.0, read=None)
    assert_equal(timeout.connect.value(), 3.0)
    assert_equal(timeout.write.value(), 5.0)
    assert_true(not timeout.read)
    assert_true(not Timeout.disabled().connect)


def test_invalid_timeouts() raises:
    for seconds in [0.0, -1.0, inf[DType.float64](), nan[DType.float64]()]:
        with assert_raises():
            _ = Timeout(seconds)
