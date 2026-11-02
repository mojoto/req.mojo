"""Verify precompiled consumers without linking flags or checkout imports."""

import argparse
import configparser
import os
from pathlib import Path
import shutil
import subprocess
import tempfile

from conftest import Fixtures


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--package-dir", type=Path, default=ROOT / "build")
    args = parser.parse_args()
    package = args.package_dir.resolve()
    compiler = shutil.which("mojo")
    if not compiler:
        raise RuntimeError("Run this test inside the Mojo Pixi environment")
    native_name = "libreq_curl.dylib" if os.uname().sysname == "Darwin" else "libreq_curl.so"
    with tempfile.TemporaryDirectory(prefix="req-consumer-") as temporary:
        work = Path(temporary)
        modules = work / "env/lib/mojo"
        modules.mkdir(parents=True)
        shutil.copy2(package / "req.mojoc", modules)
        shutil.copytree(package / "json", modules / "json")
        for name in ("LICENSE", "NOTICE"):
            if not (package / "licenses/json" / name).is_file():
                raise RuntimeError(f"Missing JSON {name}")
        # Changing CONDA_PREFIX alone does not change Mojo's configured import path.
        config = configparser.ConfigParser()
        config.read(Path(os.environ["MODULAR_HOME"]) / "modular.cfg")
        std = Path(config["mojo-max"]["import_path"]) / "std.mojoc"
        shutil.copy2(std, modules)
        config["mojo-max"]["import_path"] = str(modules)
        modular_home = work / "modular"
        modular_home.mkdir()
        with (modular_home / "modular.cfg").open("w") as output:
            config.write(output)
        native = modules.parent / native_name
        shutil.copy2(package / native_name, native)
        shutil.copy2(ROOT / "tests/package.mojo", work / "main.mojo")
        env = dict(os.environ, CONDA_PREFIX=str(work / "env"), MODULAR_HOME=str(modular_home))
        env.pop("REQ_NATIVE_LIB", None)
        env.pop("REQ_EXPECT_LOAD_ERROR", None)
        env.pop("REQ_EXPECT_HTTP2_UNAVAILABLE", None)
        # A negative compile proves a developer-installed json cannot fill gaps.
        (modules / "json").rename(work / "missing-json")
        missing_json = subprocess.run(
            [compiler, "build", "--Werror", "-I", str(modules), "main.mojo", "-o", "main"],
            cwd=work, env=env, capture_output=True, text=True, timeout=120,
        )
        if missing_json.returncode == 0 or "unable to locate module 'json'" not in missing_json.stderr:
            raise RuntimeError("Package test did not isolate JSON dependencies: " + missing_json.stderr)
        (work / "missing-json").rename(modules / "json")
        with Fixtures() as fixtures:
            env.update(fixtures.environment)
            command = [compiler, "run", "--Werror", "-I", str(modules), "main.mojo"]
            subprocess.run(command, cwd=work, env=env, check=True, timeout=120)
            subprocess.run(
                [compiler, "build", "--Werror", "-I", str(modules), "main.mojo", "-o", "main"],
                cwd=work, env=env, check=True, timeout=120,
            )
            subprocess.run(["./main"], cwd=work, env=env, check=True, timeout=30)
            # Fault injection verifies the capability guard before other symbols
            # are resolved, using the same installed and compiled consumer.
            stub = work / "no_http2.c"
            stub.write_text("int req_http2_supported(void) { return 0; }\n")
            stub_library = work / native_name
            shared_flag = "-dynamiclib" if os.uname().sysname == "Darwin" else "-shared"
            subprocess.run(
                [os.environ.get("CC", "cc"), "-fPIC", shared_flag,
                 str(stub), "-o", str(stub_library)],
                check=True, timeout=30,
            )
            subprocess.run(
                ["./main"], cwd=work,
                env=dict(env, REQ_NATIVE_LIB=str(stub_library), REQ_EXPECT_HTTP2_UNAVAILABLE="1"),
                check=True, timeout=30,
            )
            # Missing transport and an invalid override must report typed errors.
            missing = native.with_suffix(".missing")
            native.rename(missing)
            error_env = dict(env, REQ_EXPECT_LOAD_ERROR="1")
            subprocess.run(["./main"], cwd=work, env=error_env, check=True, timeout=30)
            subprocess.run(
                ["./main"], cwd=work,
                env=dict(error_env, REQ_NATIVE_LIB=str(work / "absent.so")),
                check=True, timeout=30,
            )
            wrong_library = "/usr/lib/libSystem.B.dylib" if os.uname().sysname == "Darwin" else "libc.so.6"
            subprocess.run(
                ["./main"], cwd=work,
                env=dict(error_env, REQ_NATIVE_LIB=wrong_library),
                check=True, timeout=30,
            )
            missing.rename(native)
            subprocess.run(
                ["./main"], cwd=work, env=dict(env, REQ_NATIVE_LIB=str(native)),
                check=True, timeout=30,
            )
        print("Req isolated package and native loading checks passed")


if __name__ == "__main__":
    main()
