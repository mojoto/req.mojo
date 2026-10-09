---
title: QueryParams
---

# QueryParams

名称区分大小写，保留重复值和插入顺序。查询字符串解析百分号转义，并将 + 解释为空格。

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

构造空映射；唯一键使用 Dict[String, String]，重复值使用 List[Tuple[String, String]]。String 重载解析不带前导 ? 的查询字符串；没有 = 的键取空值，空字符串创建空映射。错误的百分号转义抛出 InvalidURL；解码后不是有效 UTF-8 时抛出 DecodeError。

```text
def __init__(out self)

def __init__(out self, pairs: StringPairs) raises HTTPError

def __init__(out self, pairs: Dict[String, String]) raises HTTPError

def __init__(out self, query: String) raises HTTPError
```

## `get`

返回第一个匹配值的 Optional[String]，不存在则为 None。存在的空值是 Some("")，不是 None。需要重复值时使用 get_all()。

```text
def get(self, name: String) -> Optional[String]
```

```mojo
var page = params.get("page")
if page:
    print(page.value())
```

## `get_all`

按存储顺序返回所有匹配值的新 List[String]，名称不存在时返回空列表；返回列表是副本。

```text
def get_all(self, name: String) -> List[String]
```

```mojo
for tag in params.get_all("tag"):
    print(tag)
```

## `params[name]`

通过名称下标访问第一个 String 值。名称不存在时抛出 InvalidRequest，与返回 None 的 get() 不同。

```text
def __getitem__(self, name: String) raises HTTPError -> String
```

```mojo
print(params["q"])
```

## `name in params`

表达式 name in mapping 返回 Bool，判断是否存在匹配名称，包括值为空的字段。

```text
def __contains__(self, name: String) -> Bool
```

```mojo
print("q" in params)
```

## `len(params)`

len(mapping) 统计存储的键值对数量，包括重复项，不是不同名称的数量。

```text
def __len__(self) -> Int
```

```mojo
print(len(params))
```

## `items`

按插入顺序返回复制的 List[Tuple[String, String]]，可枚举字段而不丢失重复值。修改返回列表不会修改原映射。

```text
def items(self) -> StringPairs
```

```mojo
for pair in params.items():
    print(pair[0], pair[1])
```

## `add`

追加新键值对，不删除旧值，适用于协议或接口允许重复字段的场景。值按解码后的字符串保存，序列化时才编码。

```text
def add(mut self, name: String, value: String) raises HTTPError
```

```mojo
params.add("tag", "mojo")
params.add("tag", "http")
```

## `set`

将所有匹配值替换成一个键值对。替换项占据第一个匹配项的位置；新名称追加到末尾，无返回值。

```text
def set(mut self, name: String, value: String) raises HTTPError
```

```mojo
params.set("page", "2")
```

## `remove`

删除所有匹配的键值对。名称不存在时不做操作，无返回值，不因缺失抛错。

```text
def remove(mut self, name: String)
```

```mojo
params.remove("page")
```

## `merge`

按名称合并另一映射：删除本映射中对应名称的现有值，再按顺序追加对方该名称的所有值。对方没有的名称保留；这不是无条件拼接所有键值对。

```text
def merge(mut self, other: Self) raises HTTPError
```

```mojo
params.merge(req.QueryParams({"page": "3"}))
```

## `encode`

序列化为百分号编码的查询 String。form=False 时空格为 %20；form=True 时空格为 +，用于 application/x-www-form-urlencoded 请求体。重复值分别输出，空映射返回空字符串，不添加前导 ?。

```text
def encode(self, *, form: Bool = False) -> String
```

```mojo
var search = req.QueryParams({"q": "hello world"})
print(search.encode())
print(search.encode(form=True))
```

## `String(params)`

Writable 序列化采用 encode(form=False)，明确需要表单编码时使用 encode(form=True)。

```text
def write_to(self, mut writer: Some[Writer])
```
