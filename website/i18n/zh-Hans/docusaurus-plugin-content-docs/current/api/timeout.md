---
title: Timeout
---

# Timeout

Timeout 是 HTTP 函数与 Client 接受的共享超时配置值。

```mojo
import req


def main() raises:
    var timeout = req.Timeout(connect=3.0, read=15.0, write=None)
    timeout.validate()
    print(timeout.connect.value())
```

## `Timeout()`

以秒配置各阶段超时。Timeout() 将 connect/read/write 都设为 5.0；Timeout(seconds) 将三者设为同一个有限正 Float64。
命名构造器分别设置各阶段，接受 Optional[Float64]，None 只禁用该阶段。零、负数、NaN、无穷值抛出 InvalidRequest。
这些是阶段超时，不是包含所有重定向和响应处理的总耗时截止时间。

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

返回 connect/read/write 均为 None 的 Timeout。使用时应用应有合适的替代取消机制；否则停滞操作没有配置的阶段截止时间。

```text
def disabled() -> Self
```

## `validate`

修改三个公开字段后重新检查，每个值必须为 None 或有限正 Float64。无返回值，无效值抛出 InvalidRequest。客户端配置和发送时都会检查，修改字段不能绕过校验。

```text
def validate(self) raises HTTPError
```

## 字段

connect 限制建立连接，read 限制等待响应数据，write 限制发送请求数据。禁用某个阶段不会禁用其他阶段；对应失败类型为 ConnectTimeout、ReadTimeout、WriteTimeout。

```text
connect: Optional[Float64]
read: Optional[Float64]
write: Optional[Float64]
```
