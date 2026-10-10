"""Owned storage for runtime-polymorphic components."""

from std.memory import OwnedPointer, Pointer


def _destroy[T: Movable & Deinitable](address: Int):
    # Restore the exact allocation and type created by _OwnedObject.
    _ = OwnedPointer[T](
        unsafe_from_raw_pointer=Pointer[T, MutUntrackedOrigin](
            unsafe_from_address=address
        )
    )


struct _OwnedObject(Movable):
    var _address: Int
    var _destroy: def(Int) thin -> None

    def __init__[T: Movable & Deinitable](out self, var value: T):
        var allocation = OwnedPointer(value^).unsafe_take_allocation()
        self._address = Int(allocation^.unsafe_leak())
        self._destroy = _destroy[T]

    def __deinit__(deinit self):
        self._destroy(self._address)

    def pointer[T: AnyType](mut self) -> Pointer[T, origin_of(self)]:
        # Dispatchers always request the type used at construction. The origin
        # keeps this owner alive throughout calls through the dispatch table.
        return Pointer[T, origin_of(self)](unsafe_from_address=self._address)
