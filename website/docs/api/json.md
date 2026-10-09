---
title: JSONValue
---

# JSONValue

JSONValue is the native value used by request json= and Response.json(). It keeps JSON types explicit: reading a member and converting its type are separate operations.

```mojo
import req


def main() raises:
    var payload = req.JSONValue.object()
    payload.set("name", req.JSONValue("Mojo"))
    var tags = req.JSONValue.array()
    tags.append(req.JSONValue("http"))
    payload.set("tags", tags)
    print(payload.to_string())
    var parsed = req.JSONValue.parse(payload.to_string())
    print(parsed["name"].string_value())
    print(parsed["tags"][0].string_value())
```

## `JSONValue()`

Wrap a String, Int, finite Float64, Bool, or an owned native JSON Value. A String creates a JSON string value; it does not parse a JSON document. Use parse() for documents. Nonfinite floating-point input raises InvalidRequest. JSONValue is implicitly copyable and copies its underlying data.

```text
def __init__(out self, var value: Value)

def __init__(out self, *, copy: Self)

def __init__(out self, value: String)

def __init__(out self, value: Int)

def __init__(out self, value: Float64) raises HTTPError

def __init__(out self, value: Bool)
```

```mojo
var label = req.JSONValue("Mojo")
var count = req.JSONValue(3)
var enabled = req.JSONValue(True)
```

## `null`

Create a JSON null value. Passing json=JSONValue.null() sends the literal null; it is different from json=None, which supplies no JSON body.

```text
def null() -> Self
```

```mojo
var empty = req.JSONValue.null()
print(empty.to_string())
```

## `object`

Create an empty JSON object, ready for set(key, value). Returns a JSONValue rather than a Mojo Dict.

```text
def object() -> Self
```

```mojo
var user = req.JSONValue.object()
user.set("name", req.JSONValue("Mojo"))
```

## `array`

Create an empty JSON array, ready for append(value). Returns a JSONValue.

```text
def array() -> Self
```

```mojo
var tags = req.JSONValue.array()
tags.append(req.JSONValue("http"))
```

## `parse`

Parse a complete JSON document from a String. Objects, arrays, scalars, and null are supported. Invalid syntax and unpaired surrogate escapes raise JSONDecodeError. Parsing does not perform network I/O.

```text
def parse(text: String) raises HTTPError -> Self
```

```mojo
var document = req.JSONValue.parse('{"name":"Mojo","tags":["http"]}')
```

## `to_string`

Serialize the value to a JSON document String. This is useful for logs or comparison; a request json= keyword handles serialization and Content-Type automatically. A wrapped string is quoted and escaped.

```text
def to_string(self) -> String
```

## `is_null`

Return Bool indicating whether this value is JSON null. It does not convert empty strings, empty arrays, zero, or false to null.

```text
def is_null(self) -> Bool
```

```mojo
print(req.JSONValue.null().is_null())
```

## `value[key] / value[index]`

Use value[key: String] to read an object member or value[index: Int] to read an array element. Returns a new JSONValue, so typed accessors remain necessary. A missing key, invalid index, or incompatible container raises JSONDecodeError.

```text
def __getitem__(self, key: String) raises HTTPError -> Self

def __getitem__(self, index: Int) raises HTTPError -> Self
```

```mojo
print(document["name"].string_value())
print(document["tags"][0].string_value())
```

## `string_value`

Return String only when the value is a JSON string. Numbers and booleans are not implicitly converted; wrong type raises JSONDecodeError.

```text
def string_value(self) raises HTTPError -> String
```

```mojo
print(req.JSONValue("Mojo").string_value())
```

## `int_value`

Return a signed JSON integer as Int. It does not truncate floats or accept booleans or strings. Unsigned integer representations and other types raise JSONDecodeError; use float_value() to read any supported number.

```text
def int_value(self) raises HTTPError -> Int
```

```mojo
print(req.JSONValue(42).int_value())
```

## `float_value`

Return Float64 for a JSON number, converting supported signed/unsigned integer values as needed. Non-number values raise JSONDecodeError. Integer-to-float conversion can lose precision for large values.

```text
def float_value(self) raises HTTPError -> Float64
```

```mojo
print(req.JSONValue(1.5).float_value())
```

## `bool_value`

Return Bool for a JSON boolean. The strings "true" and "false", and numbers such as 0 or 1, are not accepted as booleans. Wrong type raises JSONDecodeError.

```text
def bool_value(self) raises HTTPError -> Bool
```

```mojo
print(req.JSONValue(True).bool_value())
```

## `set`

Set or replace an object member by key with another JSONValue. Returns no value and mutates this object. Using it on a non-object raises InvalidRequest. It does not create intermediate nested objects automatically.

```text
def set(mut self, key: String, value: Self) raises HTTPError
```

```mojo
user.set("name", req.JSONValue("updated"))
```

## `append`

Append a JSONValue to an array, preserving order. Returns no value and mutates the array. A non-array receiver raises InvalidRequest.

```text
def append(mut self, value: Self) raises HTTPError
```

```mojo
tags.append(req.JSONValue("mojo"))
```
