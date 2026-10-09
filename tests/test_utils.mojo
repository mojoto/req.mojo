from std.testing import assert_equal, assert_raises
from req import encode_utf8, Bytes
from req._utils import decode_utf8, percent_encode, percent_decode


def test_utf8_round_trip() raises:
    assert_equal(decode_utf8(encode_utf8("hello 🔥")), "hello 🔥")
    assert_equal(decode_utf8(Bytes()), "")
    with assert_raises():
        _ = decode_utf8(Bytes([UInt8(255)]))


def test_percent_encoding() raises:
    assert_equal(percent_encode("a b+雪"), "a%20b%2B%E9%9B%AA")
    assert_equal(percent_encode("a b+雪", form=True), "a+b%2B%E9%9B%AA")
    assert_equal(percent_decode("a%20b%2B%E9%9B%AA"), "a b+雪")
    assert_equal(percent_decode("a+b%2B", form=True), "a b+")
    for value in ["%", "%0", "%GG", "%FF"]:
        with assert_raises():
            _ = percent_decode(value)


comptime TEST_FUNCTIONS = __functions_in_module()
