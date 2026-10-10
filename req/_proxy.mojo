"""Explicit and opt-in environment proxy routing."""

from std.os import getenv


def environment_proxy(scheme: String) -> String:
    var value = getenv(scheme + "_proxy")
    if not value:
        value = getenv(scheme.upper() + "_PROXY")
    if not value:
        value = getenv("all_proxy")
    if not value:
        value = getenv("ALL_PROXY")
    return value


def environment_no_proxy() -> String:
    var value = getenv("no_proxy")
    return value if value else getenv("NO_PROXY")
