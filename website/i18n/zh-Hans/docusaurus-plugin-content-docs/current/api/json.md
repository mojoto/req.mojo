---
title: JSONValue
---

# JSONValue

JSONValue 是请求 json= 与 Response.json() 使用的原生值类型。它保留明确的 JSON 类型，读取成员和提取类型值是两步操作。

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

包装 String、Int、有限 Float64、Bool 或拥有的原生 JSON Value。String 构造 JSON 字符串值，不解析 JSON 文档；解析文档使用 parse()。非有限浮点数抛出 InvalidRequest。JSONValue 可隐式复制，会复制底层数据。

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

创建 JSON null。json=JSONValue.null() 发送字面量 null，与表示未提供 JSON 请求体的 json=None 不同。

```text
def null() -> Self
```

```mojo
var empty = req.JSONValue.null()
print(empty.to_string())
```

## `object`

创建可用 set(key, value) 填充的空 JSON 对象，返回 JSONValue，不是 Mojo Dict。

```text
def object() -> Self
```

```mojo
var user = req.JSONValue.object()
user.set("name", req.JSONValue("Mojo"))
```

## `array`

创建可用 append(value) 填充的空 JSON 数组，返回 JSONValue。

```text
def array() -> Self
```

```mojo
var tags = req.JSONValue.array()
tags.append(req.JSONValue("http"))
```

## `parse`

从 String 解析完整 JSON 文档，支持对象、数组、标量和 null。非法语法和未配对代理转义抛出 JSONDecodeError，不涉及网络 I/O。

```text
def parse(text: String) raises HTTPError -> Self
```

```mojo
var document = req.JSONValue.parse('{"name":"Mojo","tags":["http"]}')
```

## `to_string`

序列化为 JSON 文档 String，适合日志或比较；请求的 json= 参数会自动序列化并处理 Content-Type。包装的字符串会带引号并转义。

```text
def to_string(self) -> String
```

## `is_null`

返回 Bool，判断值是否是 JSON null；空字符串、空数组、零和 false 不视为 null。

```text
def is_null(self) -> Bool
```

```mojo
print(req.JSONValue.null().is_null())
```

## `value[key] / value[index]`

value[key: String] 读取对象成员，value[index: Int] 读取数组元素。返回新的 JSONValue，仍需类型访问器。键不存在、下标无效或容器类型不兼容时抛出 JSONDecodeError。

```text
def __getitem__(self, key: String) raises HTTPError -> Self

def __getitem__(self, index: Int) raises HTTPError -> Self
```

```mojo
print(document["name"].string_value())
print(document["tags"][0].string_value())
```

## `string_value`

仅 JSON 字符串返回 String，不隐式转换数字或布尔值；类型错误抛出 JSONDecodeError。

```text
def string_value(self) raises HTTPError -> String
```

```mojo
print(req.JSONValue("Mojo").string_value())
```

## `int_value`

读取有符号 JSON 整数并返回 Int，不截断浮点数，也不接受布尔值或字符串。无符号整数表示和其他类型抛出 JSONDecodeError；需要读取任意数字时使用 float_value()。

```text
def int_value(self) raises HTTPError -> Int
```

```mojo
print(req.JSONValue(42).int_value())
```

## `float_value`

为 JSON 数字返回 Float64，必要时转换支持的有符号/无符号整数；非数字抛出 JSONDecodeError。大整数转浮点可能损失精度。

```text
def float_value(self) raises HTTPError -> Float64
```

```mojo
print(req.JSONValue(1.5).float_value())
```

## `bool_value`

为 JSON 布尔值返回 Bool，不接受字符串 "true"/"false" 或数字 0/1 作为布尔值；类型错误抛出 JSONDecodeError。

```text
def bool_value(self) raises HTTPError -> Bool
```

```mojo
print(req.JSONValue(True).bool_value())
```

## `set`

用另一 JSONValue 设置或替换对象成员，无返回值，原地修改对象。用于非对象时抛出 InvalidRequest，不会自动创建中间嵌套对象。

```text
def set(mut self, key: String, value: Self) raises HTTPError
```

```mojo
user.set("name", req.JSONValue("updated"))
```

## `append`

按顺序向数组追加 JSONValue，无返回值，原地修改数组；接收者不是数组时抛出 InvalidRequest。

```text
def append(mut self, value: Self) raises HTTPError
```

```mojo
tags.append(req.JSONValue("mojo"))
```
