"""Case-insensitive, ordered HTTP header fields."""

from std.collections import Dict
from ._utils import MultiItems
from ._types import StringPairs
from ._exceptions import HTTPError


struct Headers(ImplicitlyCopyable, Sized):
    var _items: MultiItems[True]

    def __init__(out self):
        self._items = MultiItems[True]()

    def __init__(out self, pairs: StringPairs) raises HTTPError:
        self._items = MultiItems[True]()
        for pair in pairs:
            self._items.add(pair[0], pair[1])

    def __init__(out self, pairs: Dict[String, String]) raises HTTPError:
        self._items = MultiItems[True]()
        for entry in pairs.items():
            self._items.add(entry.key, entry.value)

    def get(self, name: String) -> Optional[String]:
        return self._items.get(name)

    def get_all(self, name: String) -> List[String]:
        return self._items.get_all(name)

    def __contains__(self, name: String) -> Bool:
        return name in self._items

    def __getitem__(self, name: String) raises HTTPError -> String:
        return self._items[name]

    def __len__(self) -> Int:
        return len(self._items)

    def items(self) -> StringPairs:
        return self._items.items()

    def add(mut self, name: String, value: String) raises HTTPError:
        self._items.add(name, value)

    def set(mut self, name: String, value: String) raises HTTPError:
        self._items.set(name, value)

    def remove(mut self, name: String):
        self._items.remove(name)

    def merge(mut self, other: Self) raises HTTPError:
        self._items.merge(other._items)
