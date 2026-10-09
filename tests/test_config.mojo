from std.testing import assert_equal, assert_true, assert_raises
from req import Timeout
from std.math import inf, nan


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


comptime TEST_FUNCTIONS = __functions_in_module()
