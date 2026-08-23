#!/usr/bin/env python3
"""Rewrite the project identity from the upstream names to the fork names.

The working tree deliberately keeps the upstream identifiers so that merges
from upstream stay conflict-free. This script is the build step that swaps
them for the fork identity across every platform, in five passes:

    dart package   package:PiliPlus/...     ->  package:PiliSuper/...
    display name   "PiliPlus" labels        ->  "PiliSuper"
    binary name    piliplus executables     ->  pilisuper
    bundle id      com.example.piliplus     ->  org.frblanapps.pilisuper
    repository     bggRGjQaUbCoE/PiliPlus   ->  FRBLanApps/PiliSuper

Upstream attribution survives on purpose: license headers, credit lines and
git dependency URLs keep naming PiliPlus and bggRGjQaUbCoE.

--pkg-id doubles as the Android namespace and the Java/Kotlin source package,
so it must be a legal Java package name。com.pili.super 会被拒绝，因为 super
是 Java/Kotlin 保留字，用作 namespace 会导致 Android 构建失败。
"""
from __future__ import annotations

import argparse
import os
import re
import shutil
from collections.abc import Callable
from dataclasses import dataclass
from pathlib import Path

from build_common import (log_error, log_info, log_step, log_success,
                          log_warning, require_project_root)

SELF_PATH = Path(__file__).resolve()

# Never walked: VCS metadata, tool caches and build output.
SKIP_DIRECTORIES = frozenset({
    ".git", ".codegraph", ".dart_tool", ".omo", ".pytest_cache", ".fvm",
    ".idea", "build", "dist", "node_modules", "Pods", "ephemeral",
})

# Hand-maintained, because it mixes fork links with upstream credits.
MANUAL_FILES = frozenset({"README.md"})

# A line that credits upstream keeps pointing at the upstream repository.
ATTRIBUTION_LINE = re.compile(r"致敬|原作者|上上游|上游|[Uu]pstream|[Aa]cknowledg")

PACKAGE_SEGMENT = re.compile(r"[A-Za-z_][A-Za-z0-9_]*")

# Java/Kotlin keywords; a package segment may not be one of them.
RESERVED_WORDS = frozenset({
    "abstract", "assert", "boolean", "break", "byte", "case", "catch", "char",
    "class", "const", "continue", "default", "do", "double", "else", "enum",
    "extends", "final", "finally", "float", "for", "fun", "goto", "if",
    "implements", "import", "in", "infix", "init", "inline", "instanceof",
    "int", "interface", "is", "long", "native", "new", "object", "open",
    "operator", "out", "override", "package", "private", "protected", "public",
    "return", "sealed", "short", "static", "strictfp", "super", "switch",
    "synchronized", "this", "throw", "throws", "transient", "try", "typealias",
    "val", "var", "vararg", "void", "volatile", "when", "where", "while",
})


def binary_name(app_name: str) -> str:
    """Executable and desktop-entry spelling of an app name: PiliSuper -> pilisuper."""
    return re.sub(r"[^a-z0-9.+-]", "-", app_name.lower())


@dataclass(frozen=True, slots=True)
class Swap:
    """One old -> new identifier pair."""

    old: str
    new: str

    @property
    def changed(self) -> bool:
        return self.old != self.new

    def as_path(self) -> Swap:
        """The same pair written as a path: com.example.x -> com/example/x."""
        return Swap(self.old.replace(".", "/"), self.new.replace(".", "/"))


@dataclass(frozen=True, slots=True)
class Guard:
    """Text spans that a rename pass must leave byte-for-byte intact.

    `PiliPlus` also hides inside `com.example.PiliPlus` and
    `bggRGjQaUbCoE/PiliPlus`, so renaming the display name blindly would
    corrupt the bundle id and the upstream link. Those spans are reserved
    first, and any substitution overlapping one is skipped.
    """

    reserved: re.Pattern[str] | None

    @classmethod
    def over(cls, *phrases: str) -> Guard:
        wanted = [re.escape(phrase) for phrase in phrases if phrase]
        if not wanted:
            return cls(None)
        return cls(re.compile("|".join(wanted), re.IGNORECASE))

    def sub(
        self,
        pattern: re.Pattern[str],
        replace: Callable[[re.Match[str]], str],
        text: str,
    ) -> str:
        if self.reserved is None:
            return pattern.sub(replace, text)
        spans = [match.span() for match in self.reserved.finditer(text)]

        def replace_unless_reserved(match: re.Match[str]) -> str:
            start, end = match.span()
            overlaps = any(start < stop and begin < end for begin, stop in spans)
            return match.group(0) if overlaps else replace(match)

        return pattern.sub(replace_unless_reserved, text)


@dataclass(frozen=True, slots=True)
class Identity:
    """The three identifiers the rename is driven by, plus their derived forms."""

    app_name: Swap
    package: Swap
    repository: Swap

    @property
    def dart_import(self) -> Swap:
        return Swap(f"package:{self.app_name.old}/", f"package:{self.app_name.new}/")

    @property
    def binary(self) -> Swap:
        return Swap(binary_name(self.app_name.old), binary_name(self.app_name.new))

    @property
    def package_path(self) -> Swap:
        """Slash form, as used by JNI class paths and source directories."""
        return self.package.as_path()

    @property
    def guard(self) -> Guard:
        return Guard.over(
            self.package.old, self.package_path.old, self.repository.old
        )


def require_valid_java_package(pkg_id: str) -> None:
    for segment in pkg_id.split("."):
        if PACKAGE_SEGMENT.fullmatch(segment) and segment not in RESERVED_WORDS:
            continue
        log_error(
            f"{pkg_id} 不是合法的 Java/Kotlin 包名（含保留字或非法段），将导致 Android 构建失败。"
        )
        raise SystemExit(1)


def project_files() -> list[Path]:
    """Every file in the tree, skipping caches, build output and this script."""
    found: list[Path] = []
    for directory, subdirectories, names in os.walk("."):
        subdirectories[:] = sorted(
            name for name in subdirectories if name not in SKIP_DIRECTORIES
        )
        for name in names:
            path = Path(directory) / name
            if path.resolve() != SELF_PATH:
                found.append(path)
    return found


def files_under(files: list[Path], *top_level: str) -> list[Path]:
    return [path for path in files if path.parts[0] in top_level]


def read_text(path: Path) -> str | None:
    """Contents with line endings kept verbatim, or None if the file is not text."""
    try:
        with path.open(encoding="utf-8", newline="") as handle:
            return handle.read()
    except (UnicodeDecodeError, OSError):
        return None


def write_text(path: Path, content: str) -> None:
    with path.open("w", encoding="utf-8", newline="") as handle:
        handle.write(content)


def rewrite(files: list[Path], rewriter: Callable[[str], str]) -> None:
    """Apply `rewriter` to every readable file, saving only actual changes."""
    for path in files:
        before = read_text(path)
        if before is None:
            continue
        after = rewriter(before)
        if after != before:
            write_text(path, after)
            log_info(f"updated: {path}")


def declares_display_label(path: Path) -> bool:
    """Files whose plain text carries the user-visible app name."""
    parts = path.parts
    top, name = parts[0], path.name
    return any((
        name == "AndroidManifest.xml" and "android" in parts,
        name == "string.xml"
        and "res" in parts
        and any(part.startswith("values") for part in parts),
        top == "android" and "gradle" in name,
        top in {"ios", "macos"} and name.endswith(".plist"),
        name == "AppInfo.xcconfig",
        parts[:3] == ("windows", "packaging", "exe") and name == "make_config.yaml",
        parts[:2] == ("assets", "linux"),
        top == ".vscode" and name.endswith(".json"),
    ))


def rename_dart_package(identity: Identity, files: list[Path]) -> None:
    """Every `package:PiliPlus/...` import, plus pubspec's own `name:` field."""
    dart_import = identity.dart_import
    rewrite(files, lambda text: text.replace(dart_import.old, dart_import.new))

    pubspec = Path("pubspec.yaml")
    declared = read_text(pubspec)
    if declared is None:
        return
    renamed = re.sub(
        rf"^(name:\s*){re.escape(identity.app_name.old)}\b",
        rf"\g<1>{identity.app_name.new}",
        declared,
        count=1,
        flags=re.MULTILINE,
    )
    if renamed != declared:
        write_text(pubspec, renamed)
        log_info("updated: pubspec.yaml")


def rename_display_name(identity: Identity, files: list[Path]) -> None:
    """The user-visible name.

    Platform label files get it replaced wherever it stands as a word; Dart
    sources only inside string literals, so comments and license headers keep
    saying PiliPlus.
    """
    app_name, guard = identity.app_name, identity.guard

    word = re.compile(rf"\b{re.escape(app_name.old)}\b")
    rewrite(
        [path for path in files if declares_display_label(path)],
        lambda text: guard.sub(word, lambda _: app_name.new, text),
    )

    literal = re.compile(rf"(['\"]){re.escape(app_name.old)}\1")
    rewrite(
        files_under(files, "lib", "test"),
        lambda text: guard.sub(
            literal, lambda match: f"{match[1]}{app_name.new}{match[1]}", text
        ),
    )


def rename_binary_name(identity: Identity, files: list[Path]) -> None:
    """The executable name: CMake targets, window titles, launcher scripts, and
    the `piliplus_...` prefix of exported settings files."""
    binary, guard = identity.binary, identity.guard
    if not binary.changed:
        return

    word = re.compile(rf"\b{re.escape(binary.old)}\b")
    rewrite(
        files_under(files, "linux", "windows", "macos", "assets"),
        lambda text: guard.sub(word, lambda _: binary.new, text),
    )

    literal_prefix = re.compile(rf"(['\"]){re.escape(binary.old)}")
    rewrite(
        files_under(files, "lib", "test"),
        lambda text: literal_prefix.sub(rf"\g<1>{binary.new}", text),
    )


def rename_bundle_id(identity: Identity, files: list[Path]) -> None:
    """Both spellings of the old id, case-insensitively: the dotted form used by
    gradle, plists and CMake, and the slash form used by JNI class paths."""
    dotted, path_form = identity.package, identity.package_path
    spellings = re.compile(
        f"{re.escape(dotted.old)}|{re.escape(path_form.old)}", re.IGNORECASE
    )

    def to_new_spelling(match: re.Match[str]) -> str:
        return path_form.new if "/" in match.group(0) else dotted.new

    rewrite(files, lambda text: spellings.sub(to_new_spelling, text))


def rename_repository(identity: Identity, files: list[Path]) -> None:
    """Fork links, decided line by line: a line crediting upstream keeps its
    upstream link, and README.md is left to humans entirely."""
    repository = identity.repository

    def relink(text: str) -> str:
        if repository.old not in text:
            return text
        return "".join(
            line
            if ATTRIBUTION_LINE.search(line)
            else line.replace(repository.old, repository.new)
            for line in text.splitlines(keepends=True)
        )

    rewrite([path for path in files if path.name not in MANUAL_FILES], relink)


def remove_empty_parents(leaf: Path) -> None:
    """Delete the leftover `.../com/example` chain once the package moved out."""
    directory = leaf
    while directory != Path(".") and directory.is_dir() and not any(directory.iterdir()):
        directory.rmdir()
        directory = directory.parent


def find_package_directories(package_path: str) -> list[Path]:
    found: list[Path] = []
    for directory, subdirectories, _names in os.walk("."):
        subdirectories[:] = sorted(
            name for name in subdirectories if name not in SKIP_DIRECTORIES
        )
        location = Path(directory).as_posix()
        if location == package_path or location.endswith(f"/{package_path}"):
            found.append(Path(directory))
            subdirectories[:] = []  # the package folder is the leaf we move
    return found


def move_source_directories(identity: Identity) -> None:
    """Relocate `.../com/example/piliplus/` source folders to the new package."""
    old_path, new_path = identity.package_path.old, identity.package_path.new
    for source in find_package_directories(old_path):
        location = source.as_posix()
        target = Path(location[: location.rfind(old_path)] + new_path)
        if target.exists():
            log_warning(f"跳过目录移动，目标已存在: {target}")
            continue
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(source), str(target))
        remove_empty_parents(source.parent)
        log_info(f"moved: {source} -> {target}")


def rename_identity_files(identity: Identity) -> None:
    """Files named after the bundle id, such as `com.example.piliplus.desktop`."""
    old_id = re.compile(re.escape(identity.package.old), re.IGNORECASE)
    for path in project_files():
        if not old_id.search(path.name):
            continue
        target = path.with_name(old_id.sub(identity.package.new, path.name))
        if target.exists():
            log_warning(f"跳过文件重命名，目标已存在: {target}")
            continue
        path.rename(target)
        log_info(f"renamed: {path} -> {target}")


def parse_identity() -> Identity:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--pkg-id", default="org.frblanapps.pilisuper")
    parser.add_argument("--original-pkg-id", default="com.example.piliplus")
    parser.add_argument("--app-name", default="PiliSuper")
    parser.add_argument("--original-app-name", default="PiliPlus")
    parser.add_argument("--repo", default="FRBLanApps/PiliSuper")
    parser.add_argument("--original-repo", default="bggRGjQaUbCoE/PiliPlus")
    args = parser.parse_args()
    return Identity(
        app_name=Swap(args.original_app_name, args.app_name),
        package=Swap(args.original_pkg_id, args.pkg_id),
        repository=Swap(args.original_repo, args.repo),
    )


def main() -> None:
    identity = parse_identity()
    require_project_root()
    require_valid_java_package(identity.package.new)

    # Listed once, before anything moves: the content passes below all work on
    # pre-rename paths, and the structural passes walk the tree again themselves.
    files = project_files()

    if identity.app_name.changed:
        log_step("Rename Dart package")
        rename_dart_package(identity, files)
        log_step("Rename display name")
        rename_display_name(identity, files)
        log_step("Rename binary name")
        rename_binary_name(identity, files)

    if identity.package.changed:
        log_step("Rename bundle identifier")
        rename_bundle_id(identity, files)

    if identity.repository.changed:
        log_step("Rename repository references")
        rename_repository(identity, files)

    if identity.package.changed:
        # Structural changes come last, so every pass above saw the old paths.
        move_source_directories(identity)
        rename_identity_files(identity)

    log_success("项目标识已更新")


if __name__ == "__main__":
    main()
