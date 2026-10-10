"""Utils tests."""
from req import Bytes, encode_utf8
from req._utils import decode_utf8, is_token, percent_decode, percent_encode
from std.testing import assert_equal, assert_raises, assert_true


def test_utf8_round_trip() raises:
    assert_equal(decode_utf8(encode_utf8("hello 🔥")), "hello 🔥")
    assert_equal(decode_utf8(Bytes()), "")
    with assert_raises():
        _ = decode_utf8(Bytes([UInt8(255)]))


def test_encode_utf8_large_and_empty() raises:
    assert_equal(encode_utf8(""), Bytes())
    var text = String()
    for _ in range(10000):
        text += "a\x00雪🔥"
    var bytes = encode_utf8(text)
    assert_equal(len(bytes), text.byte_length())
    assert_equal(decode_utf8(bytes), text)
    bytes[0] = 0
    assert_equal(Int(text.as_bytes()[0]), 97)


def test_percent_encoding() raises:
    assert_equal(percent_encode("a b+雪"), "a%20b%2B%E9%9B%AA")
    assert_equal(percent_encode("a b+雪", form=True), "a+b%2B%E9%9B%AA")
    assert_equal(percent_decode("a%20b%2B%E9%9B%AA"), "a b+雪")
    assert_equal(percent_decode("a+b%2B", form=True), "a b+")
    for value in ["%", "%0", "%GG", "%FF"]:
        with assert_raises():
            _ = percent_decode(value)


def test_token_classifier_all_ascii_and_byte_boundaries() raises:
    var allowed = String(
        "!#$%&'*+-.^_`|~0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz"
    )
    for byte in range(128):
        var character = String(chr(byte))
        var expected = character in allowed
        for position in [0, 15, 16, 31, 32]:
            var name = Bytes(length=33, fill=65)
            name[position] = UInt8(byte)
            assert_equal(is_token(decode_utf8(name)), expected)
        assert_equal(is_token(character), expected)
    assert_true(not is_token(""))
    for length in [15, 16, 17, 31, 32, 33, 63, 64, 65]:
        var name = decode_utf8(Bytes(length=length, fill=65))
        assert_true(is_token(name))
        for character in ["雪", "🔥", "K", " ", ":", "\x00"]:
            assert_true(not is_token(name + character))
            assert_true(not is_token(character + name))
