"""Compile complete Mojo examples in documentation and release drafts."""

import os
from pathlib import Path
import re
import shlex
import subprocess
import tempfile


ROOT = Path(__file__).resolve().parents[1]


def main():
    examples = {}
    for directory in [
        ROOT / "website/docs",
        ROOT / ".github/release-notes",
        ROOT / "website/i18n/zh-Hans/docusaurus-plugin-content-docs/current",
    ]:
        for path in sorted(directory.rglob("*.md")):
            for source in re.findall(r"```mojo\n(.*?)```", path.read_text(), re.DOTALL):
                if "import req" in source and "def main() raises:" in source:
                    examples.setdefault(source.strip(), path.relative_to(ROOT))
    if not examples:
        raise RuntimeError("No complete documentation examples found")
    with tempfile.TemporaryDirectory(prefix="req-doc-examples-") as temporary:
        work = Path(temporary)
        entry = ["from std.os import getenv"]
        calls = []
        for index, (source, path) in enumerate(examples.items()):
            name = f"example_{index}"
            (work / f"{name}.mojo").write_text(source + "\n")
            entry.append(f"import {name}")
            calls.append(f"        {name}.main()")
            print(f"{name}: {path}", flush=True)
        # A runtime guard type-checks every example without contacting external sites.
        entry += ["", "def main() raises:", '    if getenv("REQ_RUN_DOC_EXAMPLES") == "1":']
        entry += calls
        (work / "main.mojo").write_text("\n".join(entry) + "\n")
        subprocess.run(
            [*shlex.split(os.environ.get("REQ_MOJO", "pixi run mojo")),
             "build", "--Werror", "-I", str(ROOT), "-I", str(work),
             str(work / "main.mojo"), "-o", str(work / "examples")],
            cwd=ROOT, check=True,
        )
    print(f"Compiled {len(examples)} distinct complete documentation examples")


if __name__ == "__main__":
    main()
