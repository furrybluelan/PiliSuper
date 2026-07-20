"""Shared, side-effect-free primitives used by the single-purpose build scripts."""
from __future__ import annotations

import io
import logging
import os
import platform
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Sequence

try:
    from rich.console import Console
    from rich.logging import RichHandler
except ImportError:
    Console = None
    RichHandler = None

if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")


def _logger() -> logging.Logger:
    logger = logging.getLogger("pilisuper.build")
    if logger.handlers:
        return logger
    logger.setLevel(logging.INFO)
    handler: logging.Handler
    if RichHandler is not None and Console is not None:
        handler = RichHandler(console=Console(stderr=True), show_time=False, show_level=False, show_path=False)
    else:
        handler = logging.StreamHandler()
    handler.setFormatter(logging.Formatter("%(message)s"))
    logger.addHandler(handler)
    return logger


LOGGER = _logger()


def log_info(message: str) -> None:
    LOGGER.info(f"INFO  {message}")


def log_success(message: str) -> None:
    LOGGER.info(f"OK    {message}")


def log_warning(message: str) -> None:
    LOGGER.warning(f"WARN  {message}")


def log_error(message: str) -> None:
    LOGGER.error(f"ERROR {message}")


def log_step(message: str) -> None:
    LOGGER.info(f"\nSTEP  {message}")


def run_command(command: Sequence[str], **kwargs: object) -> subprocess.CompletedProcess[str]:
    command_parts = [str(part) for part in command]
    if platform.system() == "Windows":
        resolved = shutil.which(command_parts[0])
        if resolved:
            command_parts[0] = resolved
    if not kwargs.get("capture_output"):
        log_info("$ " + " ".join(command_parts))
    return subprocess.run(command_parts, text=True, check=True, **kwargs)


def run_shell_command(command: str, **kwargs: object) -> subprocess.CompletedProcess[str]:
    if not kwargs.get("capture_output"):
        log_info("$ " + command)
    return subprocess.run(command, shell=True, text=True, check=True, **kwargs)


def require_command(command: str, hint: str = "") -> None:
    if not shutil.which(command):
        log_error(f"找不到 {command}。{hint}")
        raise SystemExit(1)


def require_project_root() -> None:
    if not Path("pubspec.yaml").is_file():
        log_error("找不到 pubspec.yaml；请在 Flutter 项目根目录运行。")
        raise SystemExit(1)


def flutter_build(target: str, dart_define_file: str | None, extra_args: Sequence[str]) -> None:
    require_command("flutter", "请安装 Flutter，或将其加入 PATH")
    command = ["flutter", "build", target, "--release", "--no-pub"]
    if dart_define_file and Path(dart_define_file).is_file():
        command.extend(["--dart-define-from-file", dart_define_file])
    command.extend(extra_args)
    run_command(command)


def output_path(output: str, prefix: str, platform_name: str, version: str, *parts: str, suffix: str) -> Path:
    directory = Path(output)
    directory.mkdir(parents=True, exist_ok=True)
    stem = "_".join(part for part in (prefix, platform_name, version, *parts) if part)
    return directory / f"{stem}{suffix}"
