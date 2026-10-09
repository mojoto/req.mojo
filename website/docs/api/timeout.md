---
title: Timeout
---

# Timeout

Timeout is the shared configuration value accepted by the HTTP helpers and Client.

```mojo
import req


def main() raises:
    var timeout = req.Timeout(connect=3.0, read=15.0, write=None)
    timeout.validate()
    print(timeout.connect.value())
```

## `Timeout()`

Configure independent phase timeouts in seconds. Timeout() sets connect/read/write to 5.0.
Timeout(seconds) sets the same positive finite Float64 for all three.
The keyword constructor sets phases independently; each accepts Optional[Float64]
and None disables just that phase. Zero, negative, NaN, and infinity raise
InvalidRequest. These are phase timeouts, not a total wall-clock deadline for
all redirects and response processing together.

```text
def __init__(out self)

def __init__(out self, seconds: Float64) raises HTTPError

def __init__(
    out self,
    *,
    connect: Optional[Float64] = 5.0,
    imm read: Optional[Float64] = 5.0,
    imm write: Optional[Float64] = 5.0,
) raises HTTPError
```

## `disabled`

Return a Timeout with connect, read, and write all set to None. Use it only when your application has a suitable alternative cancellation policy; a stalled operation has no configured phase deadline.

```text
def disabled() -> Self
```

## `validate`

Recheck the three public fields after modification. Each must be None or a finite positive Float64. Returns no value; invalid values raise InvalidRequest. Clients call this when configuring and sending, so mutation does not bypass timeout checks.

```text
def validate(self) raises HTTPError
```

## Fields

connect bounds connection establishment, read bounds waiting for response data, and write bounds sending request data. Disabling one does not disable the others. Matching timeout failures use ConnectTimeout, ReadTimeout, or WriteTimeout.

```text
connect: Optional[Float64]
read: Optional[Float64]
write: Optional[Float64]
```
