"""Discover and run native Mojo tests, including adapted HTTPX scenarios."""

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

from conftest import Fixtures


def collected_tests():
    """Collect test functions directly from source, without a case inventory."""
    tests = []
    names = set()
    for path in sorted(Path("tests").rglob("test_*.mojo")):
        for function in re.findall(r"^def (test_\w+)\(\) raises:", path.read_text(), re.MULTILINE):
            name = function
            if name in names:
                name += "__" + "_".join(path.with_suffix("").parts)
            if name in names:
                raise ValueError(f"Duplicate test name: {name}")
            names.add(name)
            tests.append({"name": name, "path": str(path), "function": function})
    return tests


def discovery_source(tests):
    source = [
        '"""Generated collection of native Mojo test functions."""',
        "from std.testing import TestSuite",
    ]
    modules = sorted({test["path"] for test in tests})
    aliases = {path: f"module_{index}" for index, path in enumerate(modules)}
    for path, alias in aliases.items():
        module = ".".join(Path(path).with_suffix("").parts)
        source.append(f"import {module} as {alias}")
    for test in tests:
        source.extend(["", f"def {test['name']}() raises:"])
        source.append(f"    {aliases[test['path']]}.{test['function']}()")
    source.extend([
        "", "def main() raises:",
        "    TestSuite.discover_tests[__functions_in_module()]().run()", "",
    ])
    return "\n".join(source)


def execution_report(tests, output):
    outcomes = {}
    for status, name in re.findall(
        r"^\s*(PASS|FAIL|SKIP)\s+\[[^\]]*\]\s+(\w+)\s*$", output, re.MULTILINE
    ):
        if name in outcomes:
            raise ValueError(f"Duplicate execution result: {name}")
        outcomes[name] = {"PASS": "passed", "FAIL": "failed", "SKIP": "skipped"}[status]
    cases = [
        {"name": test["name"], "source": test["path"],
         "status": outcomes.get(test["name"], "not_run")}
        for test in tests
    ]
    counts = {status: sum(case["status"] == status for case in cases)
              for status in ("passed", "failed", "skipped", "not_run")}
    report = {
        "collected_tests": len(tests), "results": counts, "tests": cases,
    }
    path = Path("build/test-results.json")
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(
        f"Test results: {counts['passed']} passed, {counts['failed']} failed, "
        f"{counts['skipped']} skipped, {counts['not_run']} not run; report: {path}",
        flush=True,
    )
    return counts


def main():
    os.chdir(Path(__file__).resolve().parents[1])
    tests = collected_tests()
    if sys.argv[1:] == ["--list"]:
        for test in tests:
            print(test["name"])
        print(f"Collected: {len(tests)} Mojo tests")
        return
    mojo = shlex.split(os.environ.get("REQ_MOJO", "pixi run mojo"))
    flags = shlex.split(os.environ.get("REQ_MOJO_FLAGS", "--Werror -I ."))
    binary = Path(".req-test-suite")
    entry = Path(".req-test-main.mojo")
    Path("build/test-results.json").unlink(missing_ok=True)
    try:
        entry.write_text(discovery_source(tests))
        subprocess.run(
            [*mojo, "build", *flags, "-o", str(binary), str(entry)],
            check=True,
        )
        with Fixtures() as fixture:
            result = subprocess.run(
                [str(binary.resolve()), *sys.argv[1:]],
                env=os.environ | fixture.environment,
                timeout=120, capture_output=True, text=True,
            )
        sys.stdout.write(result.stdout)
        sys.stderr.write(result.stderr)
        # Failed suites emit their complete result table through the exception on stderr.
        counts = execution_report(tests, result.stdout + result.stderr)
        result.check_returncode()
        if not sys.argv[1:] and counts != {
            "passed": len(tests), "failed": 0, "skipped": 0, "not_run": 0,
        }:
            raise RuntimeError("The full test collection did not pass")
    finally:
        binary.unlink(missing_ok=True)
        entry.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
