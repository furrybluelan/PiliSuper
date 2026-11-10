#!/usr/bin/env python3
"""Apply SDK, project and resolved UI-package patches for one platform.

Run flutter pub get before this script. Later builds must use --no-pub so the
resolved, patched packages are not replaced. Patch payloads are LF in Git;
this script never rewrites their line endings.
"""
from __future__ import annotations

import argparse
import json
import shutil
import subprocess
from pathlib import Path
from urllib.parse import urljoin, urlparse
from urllib.request import url2pathname

from build_common import (log_step, log_success, log_warning, require_command,
                          require_project_root, run_command)

COMMON_PATCHES = [
    "modal_barrier.patch", "text_selection.patch", "mouse_cursor.patch",
    "image_anim.patch", "layout_builder.patch", "navigation_drawer.patch",
    "popup_menu.patch", "fab.patch", "null_safety_for_selectable_region.patch",
    "selectable_region.patch", "editable_text.patch", "text_field.patch",
    "scroll_position.patch", "scrollable.patch", "scrollable_gesture.patch",
    "draggable_scrollable_sheet.patch", "scaffold.patch", "text.patch",
    "text_painter.patch", "sliver.patch", "refresh_indicator.patch",
    "double_tap_gesture.patch",
]
ANDROID_PATCHES = ["bottom_sheet_android.patch", "scroll_view.patch", "navigator.patch"]
IOS_PROJECT_PATCHES = ["bottom_sheet_ios_piliplus.patch", "geetest_ios.patch"]
IOS_FLUTTER_PATCHES = ["scroll_view.patch", "bottom_sheet_ios_flutter.patch", "navigator.patch"]
MATERIAL_PATCHES = [
    "material/modal_barrier_material.patch", "material/navigation_drawer.patch",
    "material/popup_menu.patch", "material/fab.patch", "material/text_field.patch",
    "material/scaffold.patch", "material/refresh_indicator.patch", "material/tabs.patch",
]


def apply_patch(patch_file: Path, target_root: Path) -> None:
    """Apply or positively verify an already applied patch; otherwise fail closed."""
    if not patch_file.is_file():
        raise SystemExit(f"Required patch not found: {patch_file}")
    patch_file = patch_file.resolve()
    options = [str(patch_file), "--ignore-whitespace"]
    try:
        run_command(["git", "apply", "--check", *options], cwd=target_root,
                    capture_output=True)
    except subprocess.CalledProcessError as forward_error:
        try:
            run_command(["git", "apply", "--reverse", "--check", *options],
                        cwd=target_root, capture_output=True)
        except subprocess.CalledProcessError:
            raise SystemExit(
                f"Cannot apply {patch_file.name} in {target_root}; patch is not already applied.\n"
                f"{forward_error.stderr or forward_error}"
            ) from forward_error
        log_warning(f"Already applied: {patch_file.name} in {target_root}")
    else:
        run_command(["git", "apply", *options], cwd=target_root)
        log_success(f"Applied: {patch_file.name} in {target_root}")


# Retain the public helper used by existing callers/tests.
apply_project_patch = apply_patch


def package_root(project_root: Path, name: str) -> Path:
    """Resolve the exact locked package, not the latest directory in pub cache."""
    config_path = project_root / ".dart_tool/package_config.json"
    try:
        config = json.loads(config_path.read_text(encoding="utf-8"))
        package = next(item for item in config["packages"] if item["name"] == name)
        uri = urlparse(urljoin(config_path.resolve().as_uri(), package["rootUri"]))
        if uri.scheme != "file":
            raise ValueError(f"unsupported package URI scheme: {uri.scheme}")
        path = (f"//{uri.netloc}" if uri.netloc else "") + uri.path
        root = Path(url2pathname(path)).resolve()
        if not root.is_dir():
            raise ValueError(f"package directory does not exist: {root}")
        return root
    except (OSError, ValueError, KeyError, StopIteration, TypeError) as error:
        raise SystemExit(f"Cannot resolve {name} from {config_path}; run flutter pub get first: {error}") from error


def patch_plan(platform: str) -> tuple[list[str], list[str], list[str], list[str]]:
    android = platform in ("android", "all")
    ios = platform in ("ios", "all")
    sdk = [*COMMON_PATCHES, *(ANDROID_PATCHES if android else []),
           *(IOS_FLUTTER_PATCHES if ios else [])]
    material = [*MATERIAL_PATCHES]
    if android:
        material.append("material/bottom_sheet_android.patch")
    if ios:
        material.append("material/bottom_sheet_ios_flutter_material.patch")
    return (list(dict.fromkeys(sdk)), IOS_PROJECT_PATCHES if ios else [], material,
            ["cupertino/bottom_sheet_ios_flutter.patch"] if ios else [])


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("platform", choices=["android", "ios", "macos", "windows", "linux", "all"])
    parser.add_argument("--flutter-root", type=Path, help="Explicit writable Flutter SDK to patch")
    args = parser.parse_args()
    require_project_root()
    project = Path.cwd().resolve()
    patch_dir = project / "tool/patches"
    sdk, project_patches, material, cupertino = patch_plan(args.platform)
    # Validate every input before resetting the SDK or modifying project/package sources.
    targets = [(project, project_patches), (package_root(project, "material_ui"), material)]
    if cupertino:
        targets.append((package_root(project, "cupertino_ui"), cupertino))
    for name in [*sdk, *project_patches, *material, *cupertino]:
        if not (patch_dir / name).is_file():
            raise SystemExit(f"Required patch not found: {patch_dir / name}")
    if args.flutter_root:
        flutter_root = args.flutter_root.resolve()
        if not (flutter_root / "bin/flutter").is_file() and not (flutter_root / "bin/flutter.bat").is_file():
            raise SystemExit(f"Not a Flutter SDK: {flutter_root}")
    else:
        require_command("flutter", "Install Flutter or add it to PATH")
        flutter = shutil.which("flutter")
        if flutter is None:
            raise SystemExit("Flutter executable not found")
        flutter_root = Path(flutter).resolve().parent.parent
    log_step("Reset Flutter SDK")
    run_command(["git", "reset", "--hard", "HEAD"], cwd=flutter_root)
    for root, names in [(flutter_root, sdk), *targets]:
        for name in names:
            apply_patch(patch_dir / name, root)


if __name__ == "__main__":
    main()
