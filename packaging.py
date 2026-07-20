#!/usr/bin/env python3
"""Package an existing Linux Flutter bundle; it never runs Flutter builds."""
from __future__ import annotations

import argparse
import shutil
import tempfile
from pathlib import Path

from build_common import log_success, require_command, run_command, run_shell_command


def bundle_path(arch: str) -> Path:
    path = Path(f"build/linux/{arch}/release/bundle")
    if not path.is_dir():
        raise SystemExit(f"未找到 Linux bundle: {path}；请先运行 build_linux.py")
    return path


def output_path(output: str, prefix: str, version: str, arch: str, suffix: str) -> Path:
    path = Path(output)
    path.mkdir(parents=True, exist_ok=True)
    return path / f"{prefix}_linux_{version}_{arch}{suffix}"


def package_tar(bundle: Path, destination: Path, zstd: bool) -> None:
    if zstd:
        require_command("zstd")
        run_shell_command(f"tar --use-compress-program='zstd -19 -T0' -cf '{destination}' -C '{bundle}' .")
    else:
        run_command(["tar", "-zcf", str(destination), "-C", str(bundle), "."])
    log_success(f"输出: {destination}")


def package_deb(bundle: Path, destination: Path, app_name: str, arch: str, version: str) -> None:
    require_command("dpkg-deb")
    deb_arch = {"x64": "amd64", "arm64": "arm64", "armv7": "armhf"}.get(arch, arch)
    with tempfile.TemporaryDirectory(prefix="pilisuper-deb-") as temp:
        root = Path(temp)
        app_dir = root / "opt" / app_name
        app_dir.parent.mkdir(parents=True)
        shutil.copytree(bundle, app_dir)
        control = root / "DEBIAN"
        control.mkdir()
        (control / "control").write_text(
            f"Package: {app_name}\nVersion: {version}\nArchitecture: {deb_arch}\nMaintainer: PiliSuper\nDescription: Flutter application\n",
            encoding="utf-8",
        )
        run_command(["dpkg-deb", "--build", "--root-owner-group", str(root), str(destination)])
    log_success(f"输出: {destination}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--version", required=True)
    parser.add_argument("--arch", default="x64")
    parser.add_argument("--output", default="dist")
    parser.add_argument("--output-prefix", default="PiliSuper")
    parser.add_argument("--app-name", default="PiliSuper")
    parser.add_argument("targets", nargs="+", choices=["tar.gz", "zst", "deb"])
    args = parser.parse_args()
    bundle = bundle_path(args.arch)
    for target in args.targets:
        if target == "tar.gz":
            package_tar(bundle, output_path(args.output, args.output_prefix, args.version, args.arch, ".tar.gz"), False)
        elif target == "zst":
            package_tar(bundle, output_path(args.output, args.output_prefix, args.version, args.arch, ".tar.zst"), True)
        else:
            package_deb(bundle, output_path(args.output, args.output_prefix, args.version, args.arch, ".deb"), args.app_name, args.arch, args.version)


if __name__ == "__main__":
    main()
