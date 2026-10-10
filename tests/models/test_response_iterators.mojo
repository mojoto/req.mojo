"""Incremental response iteration and boundary handling."""

from std.memory import ArcPointer
from std.os import getenv
from std.testing import assert_equal, assert_true, assert_raises
from req import (
    Client,
    Request,
    Response,
    ByteStream,
    Bytes,
    Headers,
    ErrorKind,
    encode_utf8,
)
from tests.transports._custom_helpers import State, Chunks, RecordingTransport


def _response(
    var parts: List[Bytes], headers: Headers = Headers()
) raises -> Response:
    var state = ArcPointer(State())
    return Response.from_byte_stream(
        ByteStream(Chunks(state, parts^)),
        Request("GET", "http://example.test"),
        headers=headers,
    )


def test_iter_bytes_chunk_size_matrix() raises:
    for size in [1, 2, 3, 6, 7, 8, 16, 65536]:
        var response = _response(
            [
                encode_utf8("a"),
                encode_utf8("bc"),
                encode_utf8(""),
                encode_utf8("defg"),
            ]
        )
        var result = Bytes()
        var lengths = List[Int]()
        for chunk in response.iter_bytes(size):
            lengths.append(len(chunk))
            result.extend(Span(chunk))
        assert_equal(result, encode_utf8("abcdefg"))
        for index in range(len(lengths) - 1):
            assert_equal(lengths[index], size)
        assert_true(response.is_closed())


def test_iter_bytes_cached_can_repeat() raises:
    var response = _response([encode_utf8("abcdefg")])
    _ = response.read()
    for _ in range(2):
        var chunks = List[Bytes]()
        for chunk in response.iter_bytes(3):
            chunks.append(chunk^)
        assert_equal(
            chunks, [encode_utf8("abc"), encode_utf8("def"), encode_utf8("g")]
        )


def test_iter_bytes_empty_response() raises:
    var response = _response([])
    var count = 0
    for chunk in response.iter_bytes():
        count += len(chunk)
    assert_equal(count, 0)
    assert_true(response.is_closed())


def test_iter_bytes_invalid_size_does_not_consume() raises:
    var response = _response([encode_utf8("body")])
    for size in [0, -1]:
        with assert_raises():
            _ = response.iter_bytes(size)
    assert_equal(response.read(), encode_utf8("body"))


def test_iter_bytes_creation_is_lazy() raises:
    var response = _response([encode_utf8("body")])
    _ = response.iter_bytes(2)
    assert_equal(response.read(), encode_utf8("body"))


def test_iter_bytes_consumed_stream_cannot_restart() raises:
    var response = _response([encode_utf8("body")])
    var result = Bytes()
    for chunk in response.iter_bytes():
        result.extend(Span(chunk))
    var caught = False
    try:
        for chunk in response.iter_bytes():
            result.extend(Span(chunk))
    except error:
        caught = error.kind == ErrorKind.StreamConsumed
    assert_true(caught)
    with assert_raises():
        _ = response.read()


def test_iter_bytes_partial_read_cannot_restart() raises:
    var response = _response([encode_utf8("body")])
    _ = response.read_chunk(1)
    var caught = False
    try:
        for chunk in response.iter_bytes():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.StreamConsumed
    assert_true(caught)


def test_iter_bytes_closed_stream_error() raises:
    var response = _response([encode_utf8("body")])
    response.close()
    var caught = False
    try:
        for chunk in response.iter_bytes():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.StreamClosed
    assert_true(caught)


def test_iter_bytes_break_leaves_stream_open() raises:
    var response = _response([encode_utf8("abcdef")])
    var first = Bytes()
    for chunk in response.iter_bytes(2):
        first = chunk^
        break
    assert_equal(first, encode_utf8("ab"))
    assert_true(not response.is_closed())
    response.close()
    assert_true(response.is_closed())


def test_iter_bytes_manual_next_and_prefetch() raises:
    var response = _response([encode_utf8("abcdefg")])
    var iterator = response.iter_bytes(3)
    assert_true(iterator.__has_next__())
    assert_true(iterator.__has_next__())
    assert_equal(iterator.next_chunk().value(), encode_utf8("abc"))
    assert_equal(iterator.next_chunk().value(), encode_utf8("def"))
    assert_equal(iterator.next_chunk().value(), encode_utf8("g"))
    assert_true(not iterator.next_chunk())
    assert_true(not iterator.next_chunk())


def test_iter_bytes_transport_error_is_not_swallowed() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [], fail=True)),
        Request("PUT", "http://example.test/error"),
    )
    var caught = False
    try:
        for chunk in response.iter_bytes():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.ReadError
        assert_equal(error.method.value(), "PUT")
        assert_equal(error.url.value(), "http://example.test/error")
    assert_true(caught)
    assert_equal(state[].stream_closes, 1)


def test_iter_text_unicode_character_chunk_sizes() raises:
    for size in [1, 2, 3, 8, 65536]:
        var response = _response([encode_utf8("a中"), encode_utf8("文😀éz")])
        var text = String()
        var lengths = List[Int]()
        for chunk in response.iter_text(size):
            lengths.append(len(chunk.codepoints()))
            text += chunk
        assert_equal(text, "a中文😀éz")
        for index in range(len(lengths) - 1):
            assert_equal(lengths[index], size)


def test_iter_text_utf8_split_at_decoder_boundary() raises:
    var text = String()
    for _ in range(65535):
        text += "a"
    text += "中文😀end"
    var response = _response([encode_utf8(text)])
    var result = String()
    for chunk in response.iter_text(1000):
        result += chunk
    assert_equal(result, text)


def test_iter_text_invalid_utf8_closes_stream() raises:
    var state = ArcPointer(State())
    var data = Bytes()
    data.append(255)
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [data^])),
        Request("GET", "http://example.test"),
    )
    var caught = False
    try:
        for chunk in response.iter_text():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.DecodeError
    assert_true(caught)
    assert_equal(state[].stream_closes, 1)


def test_iter_text_incomplete_utf8_at_eof() raises:
    var data = Bytes()
    data.append(240)
    data.append(159)
    var response = _response([data^])
    var caught = False
    try:
        for chunk in response.iter_text():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.DecodeError
    assert_true(caught)


def test_iter_text_invalid_utf8_sequences() raises:
    for data in [
        Bytes([UInt8(192), 175]),
        Bytes([UInt8(237), 160, 128]),
        Bytes([UInt8(244), 144, 128, 128]),
        Bytes([UInt8(226), 40, 161]),
    ]:
        var response = _response([data.copy()])
        var caught = False
        try:
            for chunk in response.iter_text():
                _ = chunk
        except error:
            caught = error.kind == ErrorKind.DecodeError
        assert_true(caught)


def test_iter_text_latin1_and_charset() raises:
    var data = Bytes()
    data.append(99)
    data.append(97)
    data.append(102)
    data.append(233)
    var response = _response(
        [data^], Headers({"Content-Type": "text/plain; charset=latin-1"})
    )
    var result = String()
    for chunk in response.iter_text(2):
        result += chunk
    assert_equal(result, "café")


def test_iter_text_explicit_encoding_overrides_charset() raises:
    var response = _response(
        [encode_utf8("中文")],
        Headers({"Content-Type": "text/plain; charset=ascii"}),
    )
    var result = String()
    for chunk in response.iter_text(1, encoding="utf-8"):
        result += chunk
    assert_equal(result, "中文")


def test_iter_text_ascii_invalid_byte() raises:
    var response = _response([encode_utf8("中文")])
    var caught = False
    try:
        for chunk in response.iter_text(encoding="ascii"):
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.DecodeError
    assert_true(caught)


def test_iter_text_invalid_parameters_do_not_consume() raises:
    var response = _response([encode_utf8("body")])
    with assert_raises():
        _ = response.iter_text(0)
    with assert_raises():
        _ = response.iter_text(encoding="unknown")
    assert_equal(response.read(), encode_utf8("body"))


def test_iter_text_preserves_transport_error() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [], fail=True)),
        Request("GET", "http://example.test"),
    )
    var caught = False
    try:
        for chunk in response.iter_text():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.ReadError
    assert_true(caught)


def test_iter_lines_universal_newlines_and_empty_lines() raises:
    var response = _response(
        [
            encode_utf8(
                "a\r\nb\rc\nd\ve\ff\x1cg\x1dh\x1ei\u0085j\u2028k\u2029\nend"
            )
        ]
    )
    var lines = List[String]()
    for line in response.iter_lines():
        lines.append(line)
    assert_equal(
        lines,
        ["a", "b", "c", "d", "e", "f", "g", "h", "i", "j", "k", "", "end"],
    )


def test_iter_lines_crlf_split_at_text_boundary() raises:
    var prefix = String()
    for _ in range(4095):
        prefix += "a"
    var response = _response([encode_utf8(prefix + "\r\n中文\r\nlast")])
    var lines = List[String]()
    for line in response.iter_lines():
        lines.append(line)
    assert_equal(lines, [prefix, "中文", "last"])


def test_iter_lines_trailing_newline_no_extra_line() raises:
    for text in ["a\n", "a\r", "a\r\n"]:
        var response = _response([encode_utf8(text)])
        var lines = List[String]()
        for line in response.iter_lines():
            lines.append(line)
        assert_equal(lines, ["a"])


def test_iter_lines_empty_body_and_blank_lines() raises:
    var empty = _response([])
    var lines = List[String]()
    for line in empty.iter_lines():
        lines.append(line)
    assert_equal(len(lines), 0)
    var response = _response([encode_utf8("\n\n")])
    for line in response.iter_lines():
        lines.append(line)
    assert_equal(lines, ["", ""])


def test_iter_lines_manual_prefetch() raises:
    var response = _response([encode_utf8("one\ntwo")])
    var iterator = response.iter_lines()
    assert_true(iterator.__has_next__())
    assert_true(iterator.__has_next__())
    assert_equal(iterator.next_chunk().value(), "one")
    assert_equal(iterator.next_chunk().value(), "two")
    assert_true(not iterator.next_chunk())


def test_iter_raw_identity_custom_stream() raises:
    var response = _response([encode_utf8("abc"), encode_utf8("def")])
    var result = Bytes()
    for chunk in response.iter_raw(2):
        result.extend(Span(chunk))
    assert_equal(result, encode_utf8("abcdef"))
    assert_true(response.is_closed())
    with assert_raises():
        _ = response.read_chunk()


def test_iter_raw_cached_response_is_consumed() raises:
    var response = Response(
        200,
        request=Request("GET", "http://example.test"),
        content=encode_utf8("body"),
    )
    var caught = False
    try:
        for chunk in response.iter_raw():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.StreamConsumed
    assert_true(caught)


def test_iter_raw_then_decoded_iteration_is_rejected() raises:
    var response = _response([encode_utf8("body")])
    var raw = Bytes()
    for chunk in response.iter_raw(1):
        raw.extend(Span(chunk))
        break
    var caught = False
    try:
        for chunk in response.iter_bytes():
            _ = chunk
    except error:
        caught = error.kind == ErrorKind.StreamConsumed
    assert_true(caught)
    response.close()


def test_iterators_response_context() raises:
    var response = _response([encode_utf8("one\ntwo")])
    var lines = List[String]()
    with response^ as context:
        for line in context.iter_lines():
            lines.append(line)
    assert_equal(lines, ["one", "two"])


def test_iter_text_empty_and_manual_prefetch() raises:
    var empty = _response([])
    var count = 0
    for chunk in empty.iter_text():
        count += chunk.byte_length()
    assert_equal(count, 0)
    var response = _response([encode_utf8("中文abc")])
    var iterator = response.iter_text(2)
    assert_true(iterator.__has_next__())
    assert_true(iterator.__has_next__())
    assert_equal(iterator.next_chunk().value(), "中文")
    assert_equal(iterator.next_chunk().value(), "ab")
    assert_equal(iterator.next_chunk().value(), "c")
    assert_true(not iterator.next_chunk())


def test_iter_lines_read_failure_propagates() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [], fail=True)),
        Request("GET", "http://example.test"),
    )
    var caught = False
    try:
        for line in response.iter_lines():
            _ = line
    except error:
        caught = error.kind == ErrorKind.ReadError
    assert_true(caught)
    assert_equal(state[].stream_closes, 1)


def test_iterators_custom_head_discards_body_and_closes() raises:
    var state = ArcPointer(State())
    var response = Response.from_byte_stream(
        ByteStream(Chunks(state, [encode_utf8("body")])),
        Request("HEAD", "http://example.test"),
    )
    var total = 0
    for chunk in response.iter_bytes():
        total += len(chunk)
    assert_equal(total, 0)
    assert_equal(state[].stream_closes, 1)
    assert_true(response.is_closed())


def test_iterators_context_bytes_raw_and_text() raises:
    var bytes = Bytes()
    with _response([encode_utf8("bytes")]) as context:
        for chunk in context.iter_bytes(2):
            bytes.extend(Span(chunk))
    assert_equal(bytes, encode_utf8("bytes"))
    var raw = Bytes()
    with _response([encode_utf8("raw")]) as context:
        for chunk in context.iter_raw(2):
            raw.extend(Span(chunk))
    assert_equal(raw, encode_utf8("raw"))
    var text = String()
    with _response([encode_utf8("中文")]) as context:
        for chunk in context.iter_text(1):
            text += chunk
    assert_equal(text, "中文")
