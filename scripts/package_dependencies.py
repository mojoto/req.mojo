"""Stage the pinned CPU JSON modules and their notices beside req.mojoc."""

import json
import os
from pathlib import Path
import shutil
import subprocess
import tomllib


ROOT = Path(__file__).resolve().parents[1]


def main():
    prefix = Path(os.environ["CONDA_PREFIX"])
    manifest = tomllib.loads((ROOT / "pixi.toml").read_text())
    expected = manifest["dependencies"]["json"]["tag"].removeprefix("v")
    records = [json.loads(path.read_text())
               for path in (prefix / "conda-meta").glob("json-*.json")]
    if len(records) != 1 or records[0]["version"] != expected:
        raise RuntimeError(f"Expected the locked json {expected} package")
    destination = ROOT / "build"
    shutil.rmtree(destination / "json", ignore_errors=True)
    shutil.copytree(prefix / "lib/mojo/json", destination / "json",
                    ignore=shutil.ignore_patterns("gpu", "__pycache__"))
    shutil.copytree(ROOT / "licenses/json", destination / "licenses/json", dirs_exist_ok=True)
    commit = subprocess.check_output(["git", "rev-parse", "HEAD"], cwd=ROOT, text=True)
    (destination / "SOURCE_COMMIT").write_text(commit)
    print(f"Staged CPU json {expected}, licenses, and source commit {commit.strip()}")


if __name__ == "__main__":
    main()
