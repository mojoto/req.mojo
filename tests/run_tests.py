"""Run independently collected compatibility cases and native regressions."""

import json
import os
import re
import shlex
import subprocess
import sys
from pathlib import Path

from conftest import Fixtures
from compat.check_baseline import validate_baseline


def collected_tests(cases, definitions):
    """Collect each compatibility identity once, then remaining regressions."""
    tests = [dict(case["execution"], source=case["source"]) for case in cases]
    covered = {call["target"] for test in tests for call in test["calls"]}
    # Every canonical row now runs independently with the same assertions.
    covered |= {
        "tests/compat/test_whatwg.mojo::test_canonical_absolute_urls",
        "tests/compat/test_whatwg.mojo::test_rejected_canonical_urls",
    }
    names = {test["name"] for test in tests}
    for target in sorted(definitions - covered):
        path, function = target.split("::")
        name = function
        if name in names:
            name += "__" + Path(path).stem
        if name in names:
            raise ValueError(f"Duplicate regression name: {name}")
        names.add(name)
        tests.append({"name": name, "calls": [{"target": target, "args": []}]})
    return tests


def discovery_source(tests):
    source = [
        '"""Generated collection of independent parameter cases."""',
        "from std.testing import TestSuite",
    ]
    modules = sorted({
        call["target"].split("::")[0] for test in tests for call in test["calls"]
    })
    aliases = {path: f"module_{index}" for index, path in enumerate(modules)}
    for path, alias in aliases.items():
        module = ".".join(Path(path).with_suffix("").parts)
        source.append(f"import {module} as {alias}")
    for test in tests:
        source.extend(["", f"def {test['name']}() raises:"])
        for call in test["calls"]:
            path, function = call["target"].split("::")
            args = ", ".join(
                str(arg) if type(arg) in (int, bool) else json.dumps(arg, ensure_ascii=False)
                for arg in call["args"]
            )
            source.append(f"    {aliases[path]}.{function}({args})")
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
        {"name": test["name"], "source": test["source"],
         "status": outcomes.get(test["name"], "not_run")}
        for test in tests if "source" in test
    ]
    counts = {status: sum(case["status"] == status for case in cases)
              for status in ("passed", "failed", "skipped", "not_run")}
    regressions = [
        {"name": test["name"], "status": outcomes.get(test["name"], "not_run")}
        for test in tests if "source" not in test
    ]
    regression_counts = {
        status: sum(test["status"] == status for test in regressions)
        for status in counts
    }
    report = {
        "collected_tests": len(tests), "compatibility": counts, "cases": cases,
        "regressions": regression_counts, "regression_cases": regressions,
    }
    path = Path("build/test-results.json")
    path.parent.mkdir(exist_ok=True)
    path.write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")
    print(
        f"Compatibility results: {counts['passed']} passed, {counts['failed']} failed, "
        f"{counts['skipped']} skipped, {counts['not_run']} not run; report: {path}",
        flush=True,
    )
    return counts


def main():
    os.chdir(Path(__file__).resolve().parents[1])
    cases, definitions = validate_baseline()
    tests = collected_tests(cases, definitions)
    if sys.argv[1:] == ["--list"]:
        for test in tests:
            print(test["name"])
        print(f"Collected: {len(cases)} compatibility cases, {len(tests) - len(cases)} regressions")
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
            "passed": len(cases), "failed": 0, "skipped": 0, "not_run": 0,
        }:
            raise RuntimeError("The full compatibility collection did not pass")
    finally:
        binary.unlink(missing_ok=True)
        entry.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
