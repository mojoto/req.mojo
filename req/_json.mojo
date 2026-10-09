"""Native JSON integration with a stable HTTP-facing value type."""

from json import loads, dumps, Value, Null, check_no_unpaired_surrogates
from std.math import isfinite
from ._exceptions import HTTPError, ErrorKind


struct JSONValue(ImplicitlyCopyable):
    var _value: Value

    def __init__(out self, var value: Value):
        self._value = value^

    def __init__(out self, *, copy: Self):
        self._value = copy._value.copy()

    def __init__(out self, value: String):
        self._value = Value(value)

    def __init__(out self, value: Int):
        self._value = Value(value)

    def __init__(out self, value: Float64) raises HTTPError:
        if not isfinite(value):
            raise HTTPError(
                ErrorKind.InvalidRequest, "JSON numbers must be finite"
            )
        self._value = Value(value)

    def __init__(out self, value: Bool):
        self._value = Value(value)

    @staticmethod
    def null() -> Self:
        return Self(Value(Null()))

    @staticmethod
    def object() -> Self:
        return Self(Value.object())

    @staticmethod
    def array() -> Self:
        return Self(Value.array())

    @staticmethod
    def parse(text: String) raises HTTPError -> Self:
        try:
            check_no_unpaired_surrogates(text)
            return Self(loads(text))
        except:
            raise HTTPError(ErrorKind.JSONDecodeError, "Invalid JSON document")

    def to_string(self) -> String:
        return dumps(self._value)

    def is_null(self) -> Bool:
        return self._value.is_null()

    def __getitem__(self, key: String) raises HTTPError -> Self:
        try:
            return Self(self._value[key])
        except:
            raise HTTPError(
                ErrorKind.JSONDecodeError, "JSON object key is missing"
            )

    def __getitem__(self, index: Int) raises HTTPError -> Self:
        try:
            return Self(self._value[index])
        except:
            raise HTTPError(
                ErrorKind.JSONDecodeError, "JSON array index is invalid"
            )

    def string_value(self) raises HTTPError -> String:
        if not self._value.is_string():
            raise HTTPError(
                ErrorKind.JSONDecodeError, "JSON value is not a string"
            )
        return self._value.string_value()

    def int_value(self) raises HTTPError -> Int:
        if not self._value.is_int():
            raise HTTPError(
                ErrorKind.JSONDecodeError, "JSON value is not an integer"
            )
        return Int(self._value.int_value())

    def float_value(self) raises HTTPError -> Float64:
        if not self._value.is_number():
            raise HTTPError(
                ErrorKind.JSONDecodeError, "JSON value is not a number"
            )
        if self._value.is_int():
            return Float64(self._value.int_value())
        if self._value.is_uint():
            return Float64(self._value.uint_value())
        return self._value.float_value()

    def bool_value(self) raises HTTPError -> Bool:
        if not self._value.is_bool():
            raise HTTPError(
                ErrorKind.JSONDecodeError, "JSON value is not a boolean"
            )
        return self._value.bool_value()

    def set(mut self, key: String, value: Self) raises HTTPError:
        try:
            self._value.set(key, value._value)
        except:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Cannot set a JSON object member"
            )

    def append(mut self, value: Self) raises HTTPError:
        try:
            self._value.append(value._value)
        except:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Cannot append a JSON array member"
            )
