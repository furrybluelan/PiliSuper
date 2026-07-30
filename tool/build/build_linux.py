#!/usr/bin/env python3
"""Build the Linux Flutter bundle; it does not package distributables."""
from __future__ import annotations

import argparse
import platform

from build_common import flutter_build, require_project_root


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--dart-define-from-file", default="pili_release.json")
    args, extra = parser.parse_known_args()
    if platform.system() != "Linux":
        parser.error("Linux 构建只能在 Linux 上执行")
    require_project_root()
    flutter_build("linux", args.dart_define_from_file, extra)


if __name__ == "__main__":
    main()
