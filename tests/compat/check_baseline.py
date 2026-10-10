"""Validate the pinned scenario inventory without downloading its source."""

import ast
import json
import re
from pathlib import Path


def validate_baseline():
    root = Path(__file__).resolve().parents[2]
    manifest = json.loads((root / "tests/compat/baseline.json").read_text())
    definitions = {
        f"{path.relative_to(root)}::{name}"
        for path in (root / "tests").rglob("test_*.mojo")
        for name in re.findall(r"^def (test_\w+)\(", path.read_text(), re.MULTILINE)
    }
    executors = {
        f"{path.relative_to(root)}::{name}"
        for path in (root / "tests/compat").glob("*.mojo")
        for name in re.findall(r"^def (\w+)\(", path.read_text(), re.MULTILINE)
    } | definitions
    seen = set()
    mapped = excluded = 0
    for module in manifest["modules"]:
        for scenario in module["tests"]:
            identity = f"{module['path']}::{scenario['name']}"
            if identity in seen:
                raise ValueError(f"Duplicate baseline scenario: {identity}")
            seen.add(identity)
            if bool(scenario.get("native")) == bool(scenario.get("excluded")):
                raise ValueError(f"Expected a mapping or an exclusion: {identity}")
            if scenario.get("native"):
                mapped += 1
                for target in scenario["native"]:
                    if target not in definitions:
                        raise ValueError(f"Missing native test: {identity} -> {target}")
            else:
                excluded += 1
    if len(seen) != manifest["baseline"]["test_functions"]:
        raise ValueError("The baseline inventory is incomplete")
    print(f"Compatibility functions: {mapped} mapped, {excluded} excluded")

    inventory = json.loads((root / "tests/compat/case_inventory.json").read_text())
    sources = set()
    families = set()
    table_keys = set()
    execution_names = set()
    case_mapped = case_excluded = 0
    for scenario in inventory["cases"]:
        identity = scenario["source"]
        if identity in sources:
            raise ValueError(f"Duplicate expanded case: {identity}")
        sources.add(identity)
        family = scenario["function"]
        if family not in seen:
            raise ValueError(f"Unknown baseline function: {family}")
        parts = identity.split("[")[0].split("::")
        if f"{parts[0]}::{parts[-1]}" != family:
            raise ValueError(f"Wrong function for expanded case: {identity}")
        families.add(family)
        if bool(scenario.get("native")) == bool(scenario.get("excluded")):
            raise ValueError(f"Expected a mapping or an exclusion: {identity}")
        if scenario.get("native"):
            case_mapped += 1
            for target in scenario["native"]:
                if target not in definitions:
                    raise ValueError(f"Missing native test: {identity} -> {target}")
            execution = scenario.get("execution", {})
            name = execution.get("name", "")
            if not re.fullmatch(r"test_compat_[a-z0-9_]+", name):
                raise ValueError(f"Missing semantic execution name: {identity}")
            if name in execution_names:
                raise ValueError(f"Duplicate execution name: {name}")
            execution_names.add(name)
            if not execution.get("calls"):
                raise ValueError(f"Missing assertions: {identity}")
            for call in execution["calls"]:
                target = call["target"]
                if target not in executors or (
                    target not in scenario["native"]
                    and not target.startswith("tests/compat/case_executors.mojo::")
                ):
                    raise ValueError(f"Invalid case executor: {identity} -> {target}")
                if any(type(arg) not in (str, int, bool) for arg in call["args"]):
                    raise ValueError(f"Invalid executor arguments: {identity}")
        else:
            case_excluded += 1
            if "execution" in scenario:
                raise ValueError(f"Excluded case has an execution: {identity}")
        if scenario.get("table_key"):
            key = scenario["table_key"]
            if key in table_keys:
                raise ValueError(f"Duplicate canonical row key: {key}")
            table_keys.add(key)
    if len(sources) != inventory["baseline_cases"] or families != seen:
        raise ValueError("The expanded case inventory is incomplete")

    table_source = (root / "tests/compat/url_cases.mojo").read_text()
    tables = re.findall(r"var cases:.*?= (\[.*?\n    \])", table_source, re.DOTALL)
    rows = [row for table in tables for row in ast.literal_eval(table)]
    if len(rows) != len(table_keys) or {row[0] for row in rows} != table_keys:
        raise ValueError("The executable canonical URL tables are incomplete")
    positive = {row[0]: list(row[1:]) for row in ast.literal_eval(tables[0])}
    rejected = {row[0]: list(row[1:]) for row in ast.literal_eval(tables[1])}
    for scenario in inventory["cases"]:
        if not scenario.get("table_key"):
            continue
        key = scenario["table_key"]
        helper = "canonical_url" if key in positive else "rejected_url"
        expected = [{
            "target": "tests/compat/case_executors.mojo::" + helper,
            "args": (positive | rejected)[key],
        }]
        if scenario["execution"]["calls"] != expected:
            raise ValueError(f"Wrong canonical URL execution: {scenario['source']}")
    print(
        f"Compatibility expanded cases: {case_mapped} mapped, "
        f"{case_excluded} excluded; {len(rows)} executable canonical URL rows",
        flush=True,
    )
    print(f"Compatibility independent executions: {len(execution_names)}", flush=True)
    return [case for case in inventory["cases"] if "native" in case], definitions


if __name__ == "__main__":
    validate_baseline()
