---
title: QueryParams
---

# QueryParams

Names are case-sensitive. Repeated values and insertion order are preserved. Query strings decode percent escapes and interpret + as a space.

```mojo
import req


def main() raises:
    var params = req.QueryParams("tag=mojo&tag=http")
    params.set("q", "hello world")
    print(params.get_all("tag"))
    print(params.encode())
    print(params.encode(form=True))
```

## `QueryParams()`

Construct an empty mapping, use a Dict[String, String] for unique keys, or a List[Tuple[String, String]] for repeated values. The String overload parses a query without the leading ?. A key with no = has an empty value; an empty string creates an empty mapping. Malformed percent escapes raise InvalidURL; decoded bytes that are not UTF-8 raise DecodeError.

```text
def __init__(out self)

def __init__(out self, pairs: StringPairs) raises HTTPError

def __init__(out self, pairs: Dict[String, String]) raises HTTPError

def __init__(out self, query: String) raises HTTPError
```

## `get`

Return the first matching value as Optional[String], or None when the name is absent. An existing empty value is Some("") rather than None. Use get_all() when duplicates matter.

```text
def get(self, name: String) -> Optional[String]
```

```mojo
var page = params.get("page")
if page:
    print(page.value())
```

## `get_all`

Return a new List[String] containing every matching value in stored order; missing names return an empty list. The returned list is a copy.

```text
def get_all(self, name: String) -> List[String]
```

```mojo
for tag in params.get_all("tag"):
    print(tag)
```

## `params[name]`

Indexing with a name returns its first value as String. Missing names raise InvalidRequest, unlike get(), which returns None.

```text
def __getitem__(self, name: String) raises HTTPError -> String
```

```mojo
print(params["q"])
```

## `name in params`

The expression name in mapping returns Bool for the existence of any matching name, including one whose value is empty.

```text
def __contains__(self, name: String) -> Bool
```

```mojo
print("q" in params)
```

## `len(params)`

len(mapping) counts stored name/value pairs, including duplicates; it is not the count of distinct names.

```text
def __len__(self) -> Int
```

```mojo
print(len(params))
```

## `items`

Return a copied List[Tuple[String, String]] in insertion order. Use it to enumerate fields without losing repeated values. Editing the result does not mutate the original mapping.

```text
def items(self) -> StringPairs
```

```mojo
for pair in params.items():
    print(pair[0], pair[1])
```

## `add`

Append a new name/value pair without removing old values. Choose this when the protocol or endpoint permits repeated fields. Values are stored as decoded strings; encoding happens on serialization.

```text
def add(mut self, name: String, value: String) raises HTTPError
```

```mojo
params.add("tag", "mojo")
params.add("tag", "http")
```

## `set`

Replace all matching values with one name/value pair. The replacement occupies the first matching position; a new name is appended. It returns no value.

```text
def set(mut self, name: String, value: String) raises HTTPError
```

```mojo
params.set("page", "2")
```

## `remove`

Remove every matching pair. A missing name is a no-op. It returns no value and does not raise for absence.

```text
def remove(mut self, name: String)
```

```mojo
params.remove("page")
```

## `merge`

Merge another mapping by name: for each incoming name remove current values, then append all incoming values in order. Names absent from the incoming mapping remain. This is replacement by name, not concatenation of every pair.

```text
def merge(mut self, other: Self) raises HTTPError
```

```mojo
params.merge(req.QueryParams({"page": "3"}))
```

## `encode`

Serialize a query String with percent-encoded names and values. With form=False, spaces become %20; with form=True, spaces become + for an application/x-www-form-urlencoded body. Repeated values are emitted separately. An empty mapping returns an empty string. No leading ? is added.

```text
def encode(self, *, form: Bool = False) -> String
```

```mojo
var search = req.QueryParams({"q": "hello world"})
print(search.encode())
print(search.encode(form=True))
```

## `String(params)`

Writable serialization uses encode(form=False). Use encode(form=True) when you specifically need form encoding.

```text
def write_to(self, mut writer: Some[Writer])
```
