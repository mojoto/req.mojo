"""Validated timeouts and transport configuration."""

from std.math import isfinite
from ._exceptions import HTTPError, ErrorKind


struct Timeout(ImplicitlyCopyable):
    var connect: Optional[Float64]
    var read: Optional[Float64]
    var write: Optional[Float64]
    var pool: Optional[Float64]

    def __init__(out self):
        self.connect = 5.0
        self.read = 5.0
        self.write = 5.0
        self.pool = 5.0

    def __init__(out self, seconds: Float64) raises HTTPError:
        self.connect = seconds
        self.read = seconds
        self.write = seconds
        self.pool = seconds
        self.validate()

    def __init__(
        out self,
        *,
        connect: Optional[Float64] = 5.0,
        imm read: Optional[Float64] = 5.0,
        imm write: Optional[Float64] = 5.0,
        pool: Optional[Float64] = 5.0,
    ) raises HTTPError:
        self.connect = connect
        self.read = read
        self.write = write
        self.pool = pool
        self.validate()

    @staticmethod
    def disabled() -> Self:
        var result = Self()
        result.connect = None
        result.read = None
        result.write = None
        result.pool = None
        return result^

    def validate(self) raises HTTPError:
        for field in [self.connect, self.read, self.write, self.pool]:
            if field and (not isfinite(field.value()) or field.value() <= 0):
                raise HTTPError(
                    ErrorKind.InvalidRequest,
                    "Timeout must be finite and positive or disabled",
                )


struct Limits(ImplicitlyCopyable):
    var max_connections: Optional[Int]
    var max_keepalive_connections: Int
    var keepalive_expiry: Optional[Float64]

    def __init__(out self):
        self.max_connections = 100
        self.max_keepalive_connections = 20
        self.keepalive_expiry = 5.0

    def __init__(
        out self,
        *,
        max_connections: Optional[Int] = 100,
        max_keepalive_connections: Int = 20,
        keepalive_expiry: Optional[Float64] = 5.0,
    ) raises HTTPError:
        self.max_connections = max_connections
        self.max_keepalive_connections = max_keepalive_connections
        self.keepalive_expiry = keepalive_expiry
        self.validate()

    def validate(self) raises HTTPError:
        if (
            self.max_connections and self.max_connections.value() <= 0
        ) or self.max_keepalive_connections < 0:
            raise HTTPError(
                ErrorKind.InvalidRequest, "Invalid connection limits"
            )
        if self.keepalive_expiry and (
            not isfinite(self.keepalive_expiry.value())
            or self.keepalive_expiry.value() < 0
        ):
            raise HTTPError(
                ErrorKind.InvalidRequest, "Invalid keepalive expiry"
            )
