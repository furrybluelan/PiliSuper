#!/usr/bin/env python3
"""Generate release metadata and update the pubspec version."""
from __future__ import annotations

import argparse
import json
import re
import subprocess
import time
from pathlib import Path

from build_common import (log_error, log_step, log_success,
                          require_project_root, run_command)


def git_output(*args: str) -> str:
    try:
        return run_command(["git", *args], capture_output=True).stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def display_version_for(platform: str, version_name: str, commit_hash: str) -> str:
    if platform == "android":
        return f"{version_name}-{commit_hash[:9]}"
    return version_name


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--platform", choices=["android", "ios", "macos", "windows", "linux"], default="linux")
    args = parser.parse_args()

    require_project_root()
    log_step("Generate release metadata")
    pubspec = Path("pubspec.yaml")
    lines = pubspec.read_text(encoding="utf-8").splitlines()
    for index, line in enumerate(lines):
        match = re.match(r"^\s*version:\s*([\d.]+)", line)
        if match:
            version_name = match.group(1)
            break
    else:
        log_error("pubspec.yaml 中未找到 version 字段")
        raise SystemExit(1)

    version_code_text = git_output("rev-list", "--count", "HEAD")
    version_code = int(version_code_text) if version_code_text.isdigit() else 0
    commit_hash = git_output("rev-parse", "HEAD") or "unknown"
    display_version = display_version_for(args.platform, version_name, commit_hash)
    version = f"{display_version}+{version_code}"

    lines[index] = f"version: {version}"
    pubspec.write_text("\n".join(lines) + "\n", encoding="utf-8")
    Path("pili_release.json").write_text(json.dumps({
        "pili.name": display_version,
        "pili.code": version_code,
        "pili.hash": commit_hash,
        "pili.time": int(time.time()),
    }, separators=(",", ":")), encoding="utf-8")
    log_success(f"pubspec.yaml version -> {version}")
    log_success("pili_release.json 已生成")


if __name__ == "__main__":
    main()
