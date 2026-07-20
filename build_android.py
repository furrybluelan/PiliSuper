#!/usr/bin/env python3
"""Build Android APKs and copy them into the release directory."""
from __future__ import annotations

import argparse
import base64
import re
import shutil
from pathlib import Path

from build_common import flutter_build, log_success, require_project_root, output_path


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", default="dist")
    parser.add_argument("--output-prefix", default="PiliSuper")
    parser.add_argument("--version", required=True)
    parser.add_argument("--dart-define-from-file", default="pili_release.json")
    parser.add_argument("--no-split", action="store_true")
    parser.add_argument("--dev", action="store_true")
    parser.add_argument("--keystore-base64")
    parser.add_argument("--key-alias")
    parser.add_argument("--key-password")
    parser.add_argument("--store-password")
    parser.add_argument("--clean-keys", action="store_true")
    args, extra = parser.parse_known_args()
    require_project_root()

    key_files = (Path("android/app/key.jks"), Path("android/key.properties"))
    if args.keystore_base64:
        if not args.key_alias or not args.key_password:
            parser.error("签名需要 --key-alias 和 --key-password")
        key_files[0].write_bytes(base64.b64decode(args.keystore_base64))
        key_files[1].write_text(
            f"storeFile=key.jks\nstorePassword={args.store_password or args.key_password}\n"
            f"keyAlias={args.key_alias}\nkeyPassword={args.key_password}\n", encoding="utf-8")
    try:
        flutter_build("apk", args.dart_define_from_file, [*([] if args.no_split else ["--split-per-abi"]), *( ["--android-project-arg", "dev=1"] if args.dev else []), *extra])
    finally:
        if args.clean_keys:
            for key_file in key_files:
                key_file.unlink(missing_ok=True)

    apk_dir = Path("build/app/outputs/flutter-apk")
    apks = list(apk_dir.glob("app-*-release.apk")) or list(apk_dir.glob("app-release.apk"))
    for apk in apks:
        match = re.match(r"app-(.+)-release\.apk", apk.name)
        abi = match.group(1) if match else "universal"
        destination = output_path(args.output, args.output_prefix, "android", args.version, abi, *( ["dev"] if args.dev else []), suffix=".apk")
        shutil.copy2(apk, destination)
        log_success(f"输出: {destination}")


if __name__ == "__main__":
    main()
