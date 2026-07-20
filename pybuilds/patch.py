#!/usr/bin/env python3
"""Reset the Flutter SDK, then apply this project's patches for one platform."""
from __future__ import annotations

import argparse
import shutil
import subprocess
from pathlib import Path

from build_common import (log_step, log_success, log_warning, require_command,
                          require_project_root, run_command)

# 所有平台都需要的补丁。顺序和原 patch.ps1 保持一致。
COMMON_PATCHES = [
    "modal_barrier.patch",
    "text_selection.patch",
    "mouse_cursor.patch",
    "image_anim.patch",
    "layout_builder.patch",
    "navigation_drawer.patch",
    "popup_menu.patch",
    "fab.patch",
    "selectable_region.patch",
    "null_safety_for_selectable_region.patch",
    "editable_text.patch",
    "text_field.patch",
]

ANDROID_PATCHES = [
    "bottom_sheet_android.patch",
    "scroll_view.patch",
    "navigator.patch",
]

# 这两项修改的是 PiliSuper 自己的 Dart 源码，必须在项目根目录应用，
# 不能和其余 Flutter SDK patches 一样传给 Flutter SDK 的 git apply。
IOS_PROJECT_PATCHES = [
    "bottom_sheet_ios_piliplus.patch",
    "geetest_ios.patch",
]

IOS_FLUTTER_PATCHES = [
    "scroll_view.patch",
    "bottom_sheet_ios_flutter.patch",
    "navigator.patch",
]

# TODO: remove
# https://github.com/flutter/flutter/issues/185052
TEXT_SELECTION_MENU_FIX_COMMIT = "beb2ad17004a1b118ff2bd09f55cee23198f6652"

# TODO: remove
# https://github.com/flutter/flutter/issues/182281
OVERSCROLL_COMMIT = "362b1de29974ffc1ed6faa826e1df870d7bec75f"


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "platform",
        choices=["android", "ios", "macos", "windows", "linux", "all"],
        help="要应用对应平台补丁的平台；all 会包含 Android 和 iOS 补丁。",
    )
    args = parser.parse_args()
    require_project_root()

    needs_android_patch = args.platform in ("android", "all")
    needs_ios_patch = args.platform in ("ios", "all")
    project_root = Path.cwd()
    patch_dir = project_root / "lib/scripts"
    #创建Flutter SDK补丁列表，先公共补丁，后平台特定补丁
    patch_names = list(COMMON_PATCHES)
    if needs_android_patch:
        patch_names.extend(ANDROID_PATCHES)
    if needs_ios_patch:
        patch_names.extend(IOS_FLUTTER_PATCHES)
    
    # 1. 按上游 patch.ps1 将 iOS 上的项目源码补丁在找Flutter SDK前在项目根目录应用。
    if needs_ios_patch:
        for patch_name in IOS_PROJECT_PATCHES:
            patch_file = patch_dir / patch_name
            log_step(f"Apply project patch {patch_name}")
            try:
                run_command(
                    ["git", "apply", str(patch_file), "--ignore-whitespace"],
                    cwd=project_root,
                )
            except subprocess.CalledProcessError as error:
                raise SystemExit(f"iOS 项目补丁应用失败: {patch_name}") from error
            log_success(f"Applied project patch: {patch_name}")

    # 2. 找到位于 <SDK>/bin/flutter 的 Flutter SDK。
    require_command("flutter", "请安装 Flutter，或将其加入 PATH")
    flutter = shutil.which("flutter")
    if flutter is None:  # require_command 已处理；保留这一行供类型检查与防御性处理。
        raise SystemExit(1)
    flutter_root = Path(flutter).resolve().parent.parent

    # 3. 配置临时提交所需身份，并恢复 SDK 到当前提交，避免上次执行留下补丁。
    run_command(["git", "config", "user.name", "ci"], cwd=flutter_root)
    run_command(["git", "config", "user.email", "ci@example.com"], cwd=flutter_root)
    log_step("Reset Flutter SDK")
    run_command(["git", "reset", "--hard", "HEAD"], cwd=flutter_root)

    # 4. 通过revert commit回退文本选择菜单
    log_step("Cherry-pick text selection menu fix")
    stashed = False
    try:
        stash_result = run_command(
            ["git", "stash", "push", "--include-untracked", "-m", "PiliSuper patch.py"],
            cwd=flutter_root,
            capture_output=True,
        )
        stashed = "No local changes to save" not in (stash_result.stdout or "")
        run_command(
            ["git", "cherry-pick", TEXT_SELECTION_MENU_FIX_COMMIT, "--no-edit"],
            cwd=flutter_root,
        )
    except subprocess.CalledProcessError:
        run_command(["git", "cherry-pick", "--abort"], cwd=flutter_root, check=False)
        log_warning("text selection menu fix cherry-pick 失败，已忽略")
    else:
        run_command(["git", "reset", "--soft", "HEAD~1"], cwd=flutter_root)
        log_success("text selection menu fix")
    finally:
        if stashed:
            run_command(["git", "stash", "pop"], cwd=flutter_root, check=False)

    # 5. 通过revert commit执行Android 所需的 Flutter commit 回退。
    if needs_android_patch:
        log_step("Revert Android overscroll change")
        stashed = False
        try:
            stash_result = run_command(
                ["git", "stash", "push", "--include-untracked", "-m", "PiliSuper patch.py"],
                cwd=flutter_root,
                capture_output=True,
            )
            stashed = "No local changes to save" not in (stash_result.stdout or "")
            run_command(["git", "revert", OVERSCROLL_COMMIT, "--no-edit"], cwd=flutter_root)
        except subprocess.CalledProcessError:
            run_command(["git", "revert", "--abort"], cwd=flutter_root, check=False)
            log_warning("overscroll indicator revert 失败，已忽略")
        else:
            run_command(["git", "reset", "--soft", "HEAD~1"], cwd=flutter_root)
            log_success("overscroll indicator revert")
        finally:
            if stashed:
                run_command(["git", "stash", "pop"], cwd=flutter_root, check=False)

    # 6. 应用 Flutter SDK 补丁。重复文件只应用一次（Android 与 iOS
    #    共享 scroll_view.patch / navigator.patch）。单个 SDK 补丁失败不阻止后续补丁。
    applied_names: set[str] = set()
    for patch_name in patch_names:
        if patch_name in applied_names:
            continue
        applied_names.add(patch_name)

        patch_file = patch_dir / patch_name
        if not patch_file.is_file():
            log_warning(f"patch 不存在，跳过: {patch_file}")
            continue

        log_step(f"Apply {patch_name}")
        try:
            run_command(
                ["git", "apply", str(patch_file.resolve()), "--ignore-whitespace"],
                cwd=flutter_root,
            )
        except subprocess.CalledProcessError:
            log_warning(f"patch 应用失败，已忽略: {patch_name}")
        else:
            log_success(f"Applied: {patch_name}")


if __name__ == "__main__":
    main()
