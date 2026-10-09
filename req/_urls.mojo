"""URLs and ordered, repeatable query parameters."""

from std.collections import Dict
from ._exceptions import HTTPError
from ._utils import MultiItems, StringPairs, find_byte, percent_decode, percent_encode
from std.format import Writable, Writer


struct QueryParams(ImplicitlyCopyable, Writable, Sized):
    var _items: MultiItems[False]

    def __init__(out self):
        self._items = MultiItems[False]()

    def __init__(out self, pairs: StringPairs) raises HTTPError:
        self._items = MultiItems[False]()
        for pair in pairs:
            self._items.add(pair[0], pair[1])

    def __init__(out self, pairs: Dict[String, String]) raises HTTPError:
        self._items = MultiItems[False]()
        for entry in pairs.items():
            self._items.add(entry.key, entry.value)

    def __init__(out self, query: String) raises HTTPError:
        self._items = MultiItems[False]()
        if query.byte_length() == 0:
            return
        for entry in query.split("&"):
            var pair = String(entry)
            var split = find_byte(pair, 61)
            var name = percent_decode(String(pair[byte=0:split]), form=True)
            var value = String()
            if split < pair.byte_length():
                value = percent_decode(String(pair[byte=split + 1:]), form=True)
            self._items.add(name, value)

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

    def encode(self, *, form: Bool = False) -> String:
        var result = String()
        for pair in self._items._pairs:
            if result.byte_length() != 0:
                result += "&"
            result += percent_encode(pair[0], form=form) + "=" + percent_encode(pair[1], form=form)
        return result^

    def write_to(self, mut writer: Some[Writer]):
        writer.write(self.encode())
