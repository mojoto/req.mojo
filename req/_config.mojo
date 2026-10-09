"""Validated timeouts and transport configuration."""

from std.math import isfinite
from ._exceptions import HTTPError, ErrorKind


struct Timeout(ImplicitlyCopyable):
    var connect: Optional[Float64]
    var read: Optional[Float64]
    var write: Optional[Float64]

    def __init__(out self):
        self.connect = 5.0
        self.read = 5.0
        self.write = 5.0

    def __init__(out self, seconds: Float64) raises HTTPError:
        self.connect = seconds
        self.read = seconds
        self.write = seconds
        self.validate()

    def __init__(out self, *, connect: Optional[Float64] = 5.0, imm read: Optional[Float64] = 5.0, imm write: Optional[Float64] = 5.0) raises HTTPError:
        self.connect = connect
        self.read = read
        self.write = write
        self.validate()

    @staticmethod
    def disabled() -> Self:
        var result = Self()
        result.connect = None
        result.read = None
        result.write = None
        return result^

    def validate(self) raises HTTPError:
        for field in [self.connect, self.read, self.write]:
            if field and (not isfinite(field.value()) or field.value() <= 0):
                raise HTTPError(ErrorKind.InvalidRequest, "Timeout must be finite and positive or disabled")
