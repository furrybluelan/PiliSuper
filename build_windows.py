#!/usr/bin/env python3
"""Build the portable Windows bundle."""
from __future__ import annotations

import argparse
import shutil
from pathlib import Path

from build_common import flutter_build, log_success, output_path, require_project_root


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="dist")
    parser.add_argument("--output-prefix", default="PiliSuper")
    parser.add_argument("--version", required=True)
    parser.add_argument("--dart-define-from-file", default="pili_release.json")
    args, extra = parser.parse_known_args()
    require_project_root()
    flutter_build("windows", args.dart_define_from_file, extra)
    bundle = Path("build/windows/x64/runner/Release")
    if not bundle.is_dir():
        parser.error(f"未找到 Windows 构建产物: {bundle}")
    destination = output_path(args.output, args.output_prefix, "windows", args.version, "x64", "portable", suffix="")
    shutil.make_archive(str(destination), "zip", bundle)
    log_success(f"输出: {destination}.zip")


if __name__ == "__main__":
    main()
