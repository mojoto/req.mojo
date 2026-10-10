---
title: Headers
---

# Headers

Names are case-insensitive. Original spelling and repeated values are preserved. Invalid header names, or values containing CR, LF, or NUL, raise InvalidRequest.

```mojo
import req


def main() raises:
    var fields = req.Headers({"Accept": "application/json"})
    fields.add("X-Tag", "one")
    fields.add("X-Tag", "two")
    print(fields.get_all("x-tag"))
    fields.set("X-Tag", "three")
    print(fields["X-Tag"])
```

## `Headers()`

Construct an empty mapping, use a Dict[String, String] for unique keys, or a List[Tuple[String, String]] for repeated values. Unlike a dictionary, a pair list can represent multiple Set-Cookie fields.

```text
def __init__(out self)

def __init__(out self, pairs: StringPairs) raises HTTPError

def __init__(out self, pairs: Dict[String, String]) raises HTTPError
```

## `get`

Return the first matching value as Optional[String], or None when the name is absent. An existing empty value is Some("") rather than None. Use get_all() when duplicates matter. All matching follows case-insensitive header names.

```text
def get(self, name: String) -> Optional[String]
```

```mojo
var value = fields.get("Content-Type")
if value:
    print(value.value())
```

## `get_all`

Return a new List[String] containing every matching value in stored order; missing names return an empty list. The returned list is a copy. All matching follows case-insensitive header names.

```text
def get_all(self, name: String) -> List[String]
```

```mojo
var cookies = fields.get_all("Set-Cookie")
for cookie in cookies:
    print(cookie)
```

## `headers[name]`

Indexing with a name returns its first value as String. Missing names raise InvalidRequest, unlike get(), which returns None. All matching follows case-insensitive header names.

```text
def __getitem__(self, name: String) raises HTTPError -> String
```

```mojo
print(fields["Accept"])
```

## `name in headers`

The expression name in mapping returns Bool for the existence of any matching name, including one whose value is empty. All matching follows case-insensitive header names.

```text
def __contains__(self, name: String) -> Bool
```

```mojo
print("accept" in fields)
```

## `len(headers)`

len(mapping) counts stored name/value pairs, including duplicates; it is not the count of distinct names. All matching follows case-insensitive header names.

```text
def __len__(self) -> Int
```

```mojo
print(len(fields))
```

## `items`

Return a copied List[Tuple[String, String]] in insertion order. Use it to enumerate fields without losing repeated values. Editing the result does not mutate the original mapping. All matching follows case-insensitive header names.

```text
def items(self) -> StringPairs
```

```mojo
for pair in fields.items():
    print(pair[0], pair[1])
```

## `add`

Append a new name/value pair without removing old values. Choose this when the protocol or endpoint permits repeated fields. Header validation occurs before appending. All matching follows case-insensitive header names.

```text
def add(mut self, name: String, value: String) raises HTTPError
```

```mojo
fields.add("X-Tag", "one")
fields.add("X-Tag", "two")
```

## `set`

Replace all matching values with one name/value pair. The replacement occupies the first matching position; a new name is appended. It returns no value. All matching follows case-insensitive header names.

```text
def set(mut self, name: String, value: String) raises HTTPError
```

```mojo
fields.set("Accept", "application/json")
```

## `remove`

Remove every matching pair. A missing name is a no-op. It returns no value and does not raise for absence. All matching follows case-insensitive header names.

```text
def remove(mut self, name: String)
```

```mojo
fields.remove("X-Tag")
```

## `merge`

Merge another mapping by name: for each incoming name remove current values, then append all incoming values in order. Names absent from the incoming mapping remain. This is replacement by name, not concatenation of every pair. All matching follows case-insensitive header names.

```text
def merge(mut self, other: Self) raises HTTPError
```

```mojo
fields.merge(req.Headers({"Accept": "text/plain"}))
print(fields["Accept"])
```
