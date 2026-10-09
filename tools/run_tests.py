"""Run Mojo tests against local HTTP and TLS fixtures."""

import os
import shlex
import subprocess
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tests"))
from conftest import Fixtures


def main():
    mojo = shlex.split(os.environ.get("REQ_MOJO", "pixi run mojo"))
    flags = shlex.split(os.environ.get("REQ_MOJO_FLAGS", "--Werror -I ."))
    links = ["-Xlinker", "build/libreq_curl.a", "-Xlinker", "-lcurl"]
    files = [Path(name) for name in sys.argv[1:]] if len(sys.argv) > 1 else sorted(Path("tests").rglob("test_*.mojo"))
    with Fixtures() as fixture:
        environment = os.environ | fixture.environment
        for file in files:
            binary = Path(".req-test-" + "-".join(file.with_suffix("").parts[1:]))
            try:
                subprocess.run([*mojo, "build", *flags, *links, "-o", str(binary), str(file)], check=True, env=environment)
                subprocess.run([str(binary.resolve())], check=True, env=environment)
            finally:
                binary.unlink(missing_ok=True)
    print(f"All {len(files)} test modules passed.", flush=True)


if __name__ == "__main__":
    main()
