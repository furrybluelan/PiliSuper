#!/usr/bin/env python3
"""Rename the Flutter project identity (package, display name, and repository).

The tree intentionally keeps upstream identifiers to ease merges; this script
is the build-time step that rewrites the whole tree to the fork identity:
Dart package, bundle id (dotted/slash + source dirs + file names), display
name, binary name, and repository references. Upstream attribution (license
headers, credits, git dependency URLs) is preserved.

全平台统一使用 --pkg-id（org.frblanapps.pilisuper），它同时也是 Android 的
namespace 与 Java/Kotlin 源码包，因此必须是合法的 Java 包名（不含保留字；
例如 com.pili.super 中的 super 会导致编译失败）。
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
from pathlib import Path
from typing import Callable

from build_common import (log_error, log_info, log_step, log_success,
                          log_warning, require_project_root)

SKIP_DIRECTORIES = {".git", ".codegraph", ".dart_tool", ".omo", ".pytest_cache",
                    ".fvm", ".idea", "build", "dist", "node_modules", "Pods",
                    "ephemeral"}

# 仓库引用替换时整行跳过的上游署名标记（README 致谢、issue 模板的“上游 issue”链接）。
ATTRIBUTION_LINE = re.compile(r"致敬|原作者|上上游|上游|[Uu]pstream|[Aa]cknowledg")
# README 同时包含自仓引用与上游致谢，人工维护，不参与自动替换。
MANUAL_FILES = {"README.md"}

# Java/Kotlin 保留字：包名（同时是 Android namespace）段不允许出现。
RESERVED_WORDS = {
    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
    "class", "const", "continue", "default", "do", "double", "else", "enum",
    "extends", "final", "finally", "float", "for", "fun", "goto", "if",
    "implements", "import", "in", "infix", "init", "inline", "instanceof",
    "int", "interface", "is", "long", "native", "new", "object", "open",
    "operator", "out", "override", "package", "private", "protected", "public",
    "return", "sealed", "short", "static", "strictfp", "super", "switch",
    "synchronized", "this", "throw", "throws", "transient", "try", "typealias",
    "val", "var", "vararg", "void", "volatile", "when", "where", "while",
}

SELF_PATH = Path(__file__).resolve()


def validate_package(pkg_id: str) -> None:
    for segment in pkg_id.split("."):
        if not re.fullmatch(r"[A-Za-z_][A-Za-z0-9_]*", segment) or segment in RESERVED_WORDS:
            log_error(f"{pkg_id} 不是合法的 Java/Kotlin 包名（含保留字或非法段），将导致 Android 构建失败。")
            raise SystemExit(1)


def iter_project_files() -> list[Path]:
    files: list[Path] = []
    for root, directories, names in os.walk("."):
        directories[:] = sorted(d for d in directories if d not in SKIP_DIRECTORIES)
        for name in names:
            path = Path(root) / name
            if path.resolve() == SELF_PATH:
                continue
            files.append(path)
    return files


def read_text(path: Path) -> str | None:
    try:
        with path.open(encoding="utf-8", newline="") as handle:
            return handle.read()
    except (UnicodeDecodeError, OSError):
        return None


def write_text(path: Path, content: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(content)


def transform_files(transform: Callable[[str], str], files: list[Path]) -> None:
    for path in files:
        content = read_text(path)
        if content is None:
            continue
        updated = transform(content)
        if updated != content:
            write_text(path, updated)
            log_info(f"updated: {path}")


def protected_spans(
    text: str, original_pkg_id: str, original_repo: str
) -> list[tuple[int, int]]:
    """Spans of old identifiers (bundle id, slash form, repo path) that
    display-name/binary-name replacement must never touch — otherwise
    bggRGjQaUbCoE/PiliPlus would be corrupted into bggRGjQaUbCoE/PiliSuper."""
    identities = [original_pkg_id, original_pkg_id.replace(".", "/")]
    if original_repo:
        identities.append(original_repo)
    pattern = "|".join(re.escape(identity) for identity in identities if identity)
    if not pattern:
        return []
    return [match.span() for match in re.finditer(pattern, text, re.IGNORECASE)]


def replace_word(text: str, old: str, new: str, protected: list[tuple[int, int]]) -> str:
    """Whole-word replace that never touches bundle-id spans (com.example.PiliPlus)."""

    def substitute(match: re.Match) -> str:
        start, end = match.span()
        if any(start < span_end and span_start < end for span_start, span_end in protected):
            return match.group(0)
        return new

    return re.sub(rf"\b{re.escape(old)}\b", substitute, text)


def rename_dart_package(app_name: str, original_app_name: str, files: list[Path]) -> None:
    old_import = f"package:{original_app_name}/"
    new_import = f"package:{app_name}/"
    transform_files(lambda text: text.replace(old_import, new_import), files)
    pubspec = Path("pubspec.yaml")
    content = read_text(pubspec)
    if content is None:
        return
    updated = re.sub(
        rf"^(name:\s*){re.escape(original_app_name)}\b",
        rf"\g<1>{app_name}",
        content,
        count=1,
        flags=re.MULTILINE,
    )
    if updated != content:
        write_text(pubspec, updated)
        log_info("updated: pubspec.yaml")


def rename_bundle_id(pkg_id: str, original_pkg_id: str, files: list[Path]) -> None:
    old_slash = original_pkg_id.replace(".", "/")
    new_slash = pkg_id.replace(".", "/")
    pattern = re.compile(
        "|".join(re.escape(form) for form in {original_pkg_id, old_slash}),
        re.IGNORECASE,
    )

    def substitute(match: re.Match) -> str:
        return new_slash if "/" in match.group(0) else pkg_id

    transform_files(lambda text: pattern.sub(substitute, text), files)


def _display_label_file(path: Path) -> bool:
    parts = path.parts
    name = path.name
    if name == "AndroidManifest.xml" and "android" in parts:
        return True
    if name == "string.xml" and "res" in parts and any(part.startswith("values") for part in parts):
        return True
    if "gradle" in name and parts[0] == "android":
        return True
    if name.endswith(".plist") and parts[0] in {"ios", "macos"}:
        return True
    if name == "AppInfo.xcconfig":
        return True
    if name == "make_config.yaml" and parts[:3] == ("windows", "packaging", "exe"):
        return True
    if parts[:2] == ("assets", "linux"):
        return True
    return parts[0] == ".vscode" and name.endswith(".json")


def rename_display_name(
    app_name: str,
    original_app_name: str,
    original_pkg_id: str,
    original_repo: str,
    files: list[Path],
) -> None:
    def word_transform(text: str) -> str:
        return replace_word(
            text,
            original_app_name,
            app_name,
            protected_spans(text, original_pkg_id, original_repo),
        )

    transform_files(word_transform, [path for path in files if _display_label_file(path)])

    # lib/test 内的显示名只出现在字符串字面量里（constants.dart 的 appName）；
    # GPL 头、注释里的 PiliPlus 是上游内容，保持不动。
    quoted = re.compile(rf"(['\"]){re.escape(original_app_name)}\1")

    def quoted_transform(text: str) -> str:
        protected = protected_spans(text, original_pkg_id, original_repo)

        def substitute(match: re.Match) -> str:
            start, end = match.span()
            if any(start < span_end and span_start < end for span_start, span_end in protected):
                return match.group(0)
            return f"{match.group(1)}{app_name}{match.group(1)}"

        return quoted.sub(substitute, text)

    transform_files(quoted_transform, [p for p in files if p.parts[0] in {"lib", "test"}])


def normalize_binary_name(name: str) -> str:
    return re.sub(r"[^a-z0-9.+-]", "-", name.lower())


def rename_binary_name(
    app_name: str,
    original_app_name: str,
    original_pkg_id: str,
    original_repo: str,
    files: list[Path],
) -> None:
    old_binary = normalize_binary_name(original_app_name)
    new_binary = normalize_binary_name(app_name)
    if old_binary == new_binary:
        return

    def word_transform(text: str) -> str:
        return replace_word(
            text,
            old_binary,
            new_binary,
            protected_spans(text, original_pkg_id, original_repo),
        )

    transform_files(
        word_transform,
        [p for p in files if p.parts[0] in {"linux", "windows", "macos", "assets"}],
    )

    # lib/test 内以旧二进制名开头的字符串字面量（备份/导出文件名前缀）。
    prefix = re.compile(rf"(['\"]){re.escape(old_binary)}")

    transform_files(
        lambda text: prefix.sub(rf"\g<1>{new_binary}", text),
        [p for p in files if p.parts[0] in {"lib", "test"}],
    )


def rename_repository(repo: str, original_repo: str, files: list[Path]) -> None:
    def transform(text: str) -> str:
        if original_repo not in text:
            return text
        updated = []
        for line in text.splitlines(keepends=True):
            if original_repo in line and not ATTRIBUTION_LINE.search(line):
                line = line.replace(original_repo, repo)
            updated.append(line)
        return "".join(updated)

    transform_files(transform, [p for p in files if p.name not in MANUAL_FILES])


def _prune_empty_directories(directory: Path) -> None:
    current = directory
    while current != Path(".") and current.is_dir() and not any(current.iterdir()):
        current.rmdir()
        current = current.parent


def move_package_directories(old_slash: str, new_slash: str) -> None:
    sources: list[Path] = []
    for root, directories, _names in os.walk("."):
        directories[:] = sorted(d for d in directories if d not in SKIP_DIRECTORIES)
        posix = Path(root).as_posix()
        if posix != "." and (posix == old_slash or posix.endswith("/" + old_slash)):
            sources.append(Path(root))
            directories[:] = []
    for source in sources:
        relative = source.as_posix()
        target = Path(relative[: relative.rfind(old_slash)] + new_slash)
        if target.exists():
            log_warning(f"跳过目录移动，目标已存在: {target}")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source), str(target))
        _prune_empty_directories(source.parent)
        log_info(f"moved: {source} -> {target}")


def rename_identity_files(pkg_id: str, original_pkg_id: str) -> None:
    pattern = re.compile(re.escape(original_pkg_id), re.IGNORECASE)
    for path in iter_project_files():
        if not pattern.search(path.name):
            continue
        target = path.with_name(pattern.sub(pkg_id, path.name))
        if target.exists():
            log_warning(f"跳过文件重命名，目标已存在: {target}")
            continue
        path.rename(target)
        log_info(f"renamed: {path} -> {target}")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pkg-id", default="org.frblanapps.pilisuper")
    parser.add_argument("--original-pkg-id", default="com.example.piliplus")
    parser.add_argument("--app-name", default="PiliSuper")
    parser.add_argument("--original-app-name", default="PiliPlus")
    parser.add_argument("--repo", default="FRBLanApps/PiliSuper")
    parser.add_argument("--original-repo", default="bggRGjQaUbCoE/PiliPlus")
    args = parser.parse_args()

    require_project_root()
    validate_package(args.pkg_id)
    files = iter_project_files()

    if args.app_name != args.original_app_name:
        log_step("Rename Dart package")
        rename_dart_package(args.app_name, args.original_app_name, files)
        log_step("Rename display name")
        rename_display_name(
            args.app_name, args.original_app_name, args.original_pkg_id, args.original_repo, files
        )
        log_step("Rename binary name")
        rename_binary_name(
            args.app_name, args.original_app_name, args.original_pkg_id, args.original_repo, files
        )

    if args.pkg_id != args.original_pkg_id:
        log_step("Rename bundle identifier")
        rename_bundle_id(args.pkg_id, args.original_pkg_id, files)

    if args.repo != args.original_repo:
        log_step("Rename repository references")
        rename_repository(args.repo, args.original_repo, files)

    if args.pkg_id != args.original_pkg_id:
        # 结构性变更放在最后：前面的内容替换都基于原始路径进行。
        move_package_directories(
            args.original_pkg_id.replace(".", "/"), args.pkg_id.replace(".", "/")
        )
        rename_identity_files(args.pkg_id, args.original_pkg_id)

    log_success("项目标识已更新")


if __name__ == "__main__":
    main()
