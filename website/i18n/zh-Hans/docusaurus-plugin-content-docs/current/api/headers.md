---
title: Headers
---

# Headers

名称不区分大小写，保留原始拼写和重复值。非法名称或包含 CR、LF、NUL 的值抛出 InvalidRequest。

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

构造空映射；唯一键使用 Dict[String, String]，重复值使用 List[Tuple[String, String]]。键值对列表可以表示多个 Set-Cookie 字段，普通字典做不到。

```text
def __init__(out self)

def __init__(out self, pairs: StringPairs) raises HTTPError

def __init__(out self, pairs: Dict[String, String]) raises HTTPError
```

## `get`

返回第一个匹配值的 Optional[String]，不存在则为 None。存在的空值是 Some("")，不是 None。需要重复值时使用 get_all()。

```text
def get(self, name: String) -> Optional[String]
```

```mojo
var value = fields.get("Content-Type")
if value:
    print(value.value())
```

## `get_all`

按存储顺序返回所有匹配值的新 List[String]，名称不存在时返回空列表；返回列表是副本。

```text
def get_all(self, name: String) -> List[String]
```

```mojo
var cookies = fields.get_all("Set-Cookie")
for cookie in cookies:
    print(cookie)
```

## `headers[name]`

通过名称下标访问第一个 String 值。名称不存在时抛出 InvalidRequest，与返回 None 的 get() 不同。

```text
def __getitem__(self, name: String) raises HTTPError -> String
```

```mojo
print(fields["Accept"])
```

## `name in headers`

表达式 name in mapping 返回 Bool，判断是否存在匹配名称，包括值为空的字段。

```text
def __contains__(self, name: String) -> Bool
```

```mojo
print("accept" in fields)
```

## `len(headers)`

len(mapping) 统计存储的键值对数量，包括重复项，不是不同名称的数量。

```text
def __len__(self) -> Int
```

```mojo
print(len(fields))
```

## `items`

按插入顺序返回复制的 List[Tuple[String, String]]，可枚举字段而不丢失重复值。修改返回列表不会修改原映射。

```text
def items(self) -> StringPairs
```

```mojo
for pair in fields.items():
    print(pair[0], pair[1])
```

## `add`

追加新键值对，不删除旧值，适用于协议或接口允许重复字段的场景。追加前进行请求头校验。

```text
def add(mut self, name: String, value: String) raises HTTPError
```

```mojo
fields.add("X-Tag", "one")
fields.add("X-Tag", "two")
```

## `set`

将所有匹配值替换成一个键值对。替换项占据第一个匹配项的位置；新名称追加到末尾，无返回值。

```text
def set(mut self, name: String, value: String) raises HTTPError
```

```mojo
fields.set("Accept", "application/json")
```

## `remove`

删除所有匹配的键值对。名称不存在时不做操作，无返回值，不因缺失抛错。

```text
def remove(mut self, name: String)
```

```mojo
fields.remove("X-Tag")
```

## `merge`

按名称合并另一映射：删除本映射中对应名称的现有值，再按顺序追加对方该名称的所有值。对方没有的名称保留；这不是无条件拼接所有键值对。

```text
def merge(mut self, other: Self) raises HTTPError
```

```mojo
fields.merge(req.Headers({"Accept": "text/plain"}))
print(fields["Accept"])
```
