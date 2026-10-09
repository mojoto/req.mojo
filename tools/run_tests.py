"""Discover all Mojo test modules and run one executable against local fixtures."""

import os
import shlex
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests"))
from conftest import Fixtures


def discovery_source(modules):
    source = [
        '"""Generated module discovery for one Mojo test executable."""',
        "from std.testing import TestSuite",
    ]
    for index, path in enumerate(modules):
        module = ".".join(path.with_suffix("").parts)
        source.append(f"import {module} as module_{index}")
    source.extend(["", "def main() raises:", "    var suite = TestSuite()", "    try:"])
    for index in range(len(modules)):
        source.extend([
            f"        var discovered_{index} = TestSuite.discover_tests[module_{index}.TEST_FUNCTIONS]()",
            f"        if len(discovered_{index}.tests) == 0:",
            f"            discovered_{index}^.abandon()",
            f'            raise Error("No tests discovered in {modules[index]}")',
            f"        suite.tests.extend(discovered_{index}.tests.copy())",
            f"        discovered_{index}^.abandon()",
        ])
    source.extend([
        "    except error:",
        "        suite^.abandon()",
        "        raise error",
        "    if len(suite.tests) == 0:",
        "        suite^.abandon()",
        '        raise Error("No tests were discovered")',
        "    suite^.run()",
        "",
    ])
    return "\n".join(source)


def main():
    os.chdir(Path(__file__).resolve().parents[1])
    mojo = shlex.split(os.environ.get("REQ_MOJO", "pixi run mojo"))
    flags = shlex.split(os.environ.get("REQ_MOJO_FLAGS", "--Werror -I ."))
    links = ["-Xlinker", "build/libreq_curl.a", "-Xlinker", "-lcurl"]
    binary = Path(".req-test-suite")
    entry = Path(".req-test-main.mojo")
    modules = sorted(Path("tests").rglob("test_*.mojo"))
    if not modules:
        raise RuntimeError("No test modules were found")
    try:
        entry.write_text(discovery_source(modules))
        subprocess.run(
            [*mojo, "build", *flags, *links, "-o", str(binary), str(entry)],
            check=True,
        )
        with Fixtures() as fixture:
            subprocess.run(
                [str(binary.resolve()), *sys.argv[1:]],
                check=True,
                env=os.environ | fixture.environment,
                timeout=120,
            )
    finally:
        binary.unlink(missing_ok=True)
        entry.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
