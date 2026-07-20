#!/usr/bin/env python3
"""Rename the Flutter project identity (package, display name, and repository)."""
from __future__ import annotations

import argparse
import re
from pathlib import Path

from build_common import log_info, log_step, log_success, log_warning, require_command, require_project_root, run_command

SKIP_DIRECTORIES = {".git", ".dart_tool", "build", "Pods", "ephemeral"}


def replace_in_files(old: str, new: str, patterns: list[str]) -> None:
    for pattern in patterns:
        for path in Path(".").glob(pattern):
            if not path.is_file() or any(part in SKIP_DIRECTORIES for part in path.parts):
                continue
            try:
                content = path.read_text(encoding="utf-8")
                if old in content:
                    path.write_text(content.replace(old, new), encoding="utf-8")
                    log_info(f"updated: {path}")
            except UnicodeDecodeError:
                continue


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pkg-id", default="com.pili.super")
    parser.add_argument("--original-pkg-id", default="com.example.piliplus")
    parser.add_argument("--app-name", default="PiliSuper")
    parser.add_argument("--original-app-name", default="PiliPlus")
    parser.add_argument("--repo", default="FRBLanApps/PiliSuper")
    parser.add_argument("--original-repo", default="bggRGjQaUbCoE/PiliPlus")
    args = parser.parse_args()

    require_project_root()
    if args.app_name != args.original_app_name:
        log_step("Rename Dart package")
        replace_in_files(f"package:{args.original_app_name}/", f"package:{args.app_name}/", ["**/*.dart", "**/*.patch"])
        pubspec = Path("pubspec.yaml")
        pubspec.write_text(re.sub(r"^(name:\s+)" + re.escape(args.original_app_name), r"\g<1>" + args.app_name, pubspec.read_text(encoding="utf-8"), flags=re.MULTILINE), encoding="utf-8")

    if args.pkg_id != args.original_pkg_id:
        log_step("Rename native package path")
        replace_in_files(args.original_pkg_id.replace(".", "/"), args.pkg_id.replace(".", "/"), ["android/**/*", "ios/**/*", "macos/**/*", "linux/**/*", "windows/**/*"])

    if args.repo != args.original_repo:
        log_step("Rename repository references")
        replace_in_files(args.original_repo, args.repo, ["assets/linux/**/*", "lib/**/*.dart", "windows/packaging/exe/make_config.yaml"])

    require_command("rename", "请先运行：dart pub global activate rename")
    run_command(["rename", "setBundleId", "--value", args.pkg_id])
    run_command(["rename", "setAppName", "--value", args.app_name])
    log_success("项目标识已更新")


if __name__ == "__main__":
    main()
