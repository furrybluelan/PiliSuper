#!/usr/bin/env python3
"""Build a Windows portable archive or an Inno Setup installer."""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from build_common import (
    flutter_build,
    log_success,
    output_path,
    require_command,
    require_project_root,
    run_command,
)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="dist")
    parser.add_argument("--output-prefix", default="PiliSuper")
    parser.add_argument("--version", required=True)
    parser.add_argument("--dart-define-from-file", default="pili_release.json")
    parser.add_argument(
        "--installer",
        action="store_true",
        help="Use fastforge and Inno Setup to build a Windows installer instead of a portable ZIP.",
    )
    args, extra = parser.parse_known_args()
    require_project_root()

    if args.installer:
        require_command("fastforge", "请先运行：dart pub global activate fastforge")
        output_dir = Path(args.output)
        output_dir.mkdir(parents=True, exist_ok=True)
        existing_installers = set(output_dir.rglob("*.exe"))
        fastforge_args = [
            "fastforge",
            "package",
            "--platform",
            "windows",
            "--targets",
            "exe",
        ]
        if Path(args.dart_define_from_file).is_file():
            fastforge_args.extend(
                [
                    "--flutter-build-args",
                    f"dart-define-from-file={args.dart_define_from_file}",
                ]
            )
        fastforge_args.extend(extra)
        run_command(fastforge_args)

        installers = [path for path in output_dir.rglob("*.exe") if path not in existing_installers]
        if not installers:
            parser.error("fastforge 没有生成 .exe 安装程序")
        if len(installers) != 1:
            parser.error(f"fastforge 生成了多个安装程序: {installers}")
        destination = output_path(args.output, args.output_prefix, "windows", args.version, "x64", "setup", suffix=".exe")
        if installers[0].resolve() != destination.resolve():
            shutil.copy2(installers[0], destination)
        log_success(f"输出: {destination}")
        return

    flutter_build("windows", args.dart_define_from_file, extra)
    bundle = Path("build/windows/x64/runner/Release")
    if not bundle.is_dir():
        parser.error(f"未找到 Windows 构建产物: {bundle}")
    destination = output_path(args.output, args.output_prefix, "windows", args.version, "x64", "portable", suffix="")
    shutil.make_archive(str(destination), "zip", bundle)
    log_success(f"输出: {destination}.zip")


if __name__ == "__main__":
    main()
