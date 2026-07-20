#!/usr/bin/env python3
"""Build a macOS application and package it as DMG or ZIP."""
from __future__ import annotations

import argparse
import platform
import shutil
from pathlib import Path

from build_common import flutter_build, log_success, log_warning, output_path, require_project_root, run_shell_command


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="dist")
    parser.add_argument("--output-prefix", default="PiliSuper")
    parser.add_argument("--version", required=True)
    parser.add_argument("--dart-define-from-file", default="pili_release.json")
    args, extra = parser.parse_known_args()
    if platform.system() != "Darwin":
        parser.error("macOS 构建只能在 macOS 上执行")
    require_project_root()
    flutter_build("macos", args.dart_define_from_file, extra)
    app = next(Path("build/macos/Build/Products/Release").glob("*.app"), None)
    if app is None:
        parser.error("未找到 .app 构建产物")
    if shutil.which("create-dmg"):
        run_shell_command(f'create-dmg "{app}"', check=False)
        dmg = next(Path(".").glob("*.dmg"), None)
        if dmg:
            destination = output_path(args.output, args.output_prefix, "macos", args.version, suffix=".dmg")
            shutil.move(dmg, destination)
            log_success(f"输出: {destination}")
            return
    log_warning("create-dmg 未安装，改为 ZIP")
    destination = output_path(args.output, args.output_prefix, "macos", args.version, suffix=".zip")
    run_shell_command(f'zip -r9 "{destination}" "{app}"')
    log_success(f"输出: {destination}")


if __name__ == "__main__":
    main()
