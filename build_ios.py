#!/usr/bin/env python3
"""Build an unsigned iOS IPA."""
from __future__ import annotations

import argparse
import platform
import shutil
from pathlib import Path

from build_common import flutter_build, log_success, output_path, require_project_root, run_shell_command


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="dist")
    parser.add_argument("--output-prefix", default="PiliSuper")
    parser.add_argument("--version", required=True)
    parser.add_argument("--dart-define-from-file", default="pili_release.json")
    args, extra = parser.parse_known_args()
    if platform.system() != "Darwin":
        parser.error("iOS 构建只能在 macOS 上执行")
    require_project_root()
    flutter_build("ios", args.dart_define_from_file, ["--no-codesign", *extra])

    payload = Path("Payload")
    if payload.is_symlink():
        payload.unlink()
    elif payload.exists():
        shutil.rmtree(payload)

    payload.symlink_to("build/ios/iphoneos")
    destination = output_path(args.output, args.output_prefix, "ios", args.version, suffix=".ipa")
    try:
        run_shell_command('find Payload/Runner.app/Frameworks -type d -name "*.framework" -exec codesign --force --sign - --preserve-metadata=identifier,entitlements {} \\;', check=False)
        run_shell_command(f'zip -r9 "{destination}" Payload/Runner.app')
    finally:
        # Payload 是指向 build/ios/iphoneos 的符号链接，不能用 rmtree 删除。
        payload.unlink(missing_ok=True)
    log_success(f"输出: {destination}")


if __name__ == "__main__":
    main()
