#!/usr/bin/env python3
"""
Flutter 多平台构建脚本
移植自 lib/scripts/build.ps1

用法:
  python build.py android
  python build.py android --pkg-id com.myfork.app --app-name my_fork --sign
  python build.py linux --linux-targets tar.gz deb rpm arch appimage
  python build.py all --pkg-id com.myfork.app --output dist/
  python build.py android -- --obfuscate --split-debug-info=./debug
"""

import argparse
import io
import json
import os
import platform as _sys_platform
import re
import shutil
import types
import subprocess
import sys
import textwrap
import time
from pathlib import Path

# Windows stdout UTF-8（▶ 等字符在 cp1252 下无法输出）
if sys.platform == "win32":
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding="utf-8", errors="replace")
    sys.stderr = io.TextIOWrapper(sys.stderr.buffer, encoding="utf-8", errors="replace")

# ══════════════════════════════════════════════════════════════════
#  输出工具
# ══════════════════════════════════════════════════════════════════


class C:
    RED = "\033[91m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    CYAN = "\033[96m"
    BOLD = "\033[1m"
    RESET = "\033[0m"


def info(m):
    print(f"{C.CYAN}[INFO]{C.RESET}  {m}")


def ok(m):
    print(f"{C.GREEN}[ OK ]{C.RESET}  {m}")


def warn(m):
    print(f"{C.YELLOW}[WARN]{C.RESET}  {m}")


def err(m):
    print(f"{C.RED}[ERR ]{C.RESET}  {m}")


def step(m):
    print(f"\n{C.BOLD}{C.CYAN}▶ {m}{C.RESET}")


# ══════════════════════════════════════════════════════════════════
#  Shell 工具
# ══════════════════════════════════════════════════════════════════

_IS_WIN = _sys_platform.system() == "Windows"


def _resolve_cmd(cmd: list) -> list:
    """
    Windows 上 flutter / dart 等工具是 .bat 文件，
    subprocess shell=False 找不到，用 shutil.which 解析完整路径。
    """
    if not _IS_WIN:
        return cmd
    resolved = shutil.which(cmd[0])
    if resolved:
        cmd = [resolved] + cmd[1:]
    return cmd


def run(cmd, cwd=None, check=True, capture=False, env=None):
    merged = {**os.environ, **(env or {})}
    if isinstance(cmd, str):
        cmd = cmd.split()
    cmd = _resolve_cmd([str(c) for c in cmd])
    if not capture:
        info("$ " + " ".join(cmd))
    return subprocess.run(
        cmd, cwd=cwd, check=check, capture_output=capture, text=True, env=merged
    )


def sh(cmd, cwd=None, check=True, capture=False, env=None):
    merged = {**os.environ, **(env or {})}
    if not capture:
        info("$ " + cmd)
    return subprocess.run(
        cmd,
        shell=True,
        cwd=cwd,
        check=check,
        capture_output=capture,
        text=True,
        env=merged,
    )


def git_out(args):
    try:
        return run(["git"] + args, capture=True).stdout.strip()
    except subprocess.CalledProcessError:
        return ""


def need(tool, hint=""):
    if not shutil.which(tool):
        err(f"找不到 {tool}。{hint}")
        sys.exit(1)


# ══════════════════════════════════════════════════════════════════
#  pubspec 读写
# ══════════════════════════════════════════════════════════════════


def pubspec_read() -> str:
    return Path("pubspec.yaml").read_text(encoding="utf-8")


def pubspec_name() -> str:
    m = re.search(r"^name:\s+(\S+)", pubspec_read(), re.MULTILINE)
    return m.group(1) if m else "app"


def pubspec_version_base() -> str:
    m = re.search(r"^version:\s*([\d.]+)", pubspec_read(), re.MULTILINE)
    return m.group(1) if m else "0.0.0"


# ══════════════════════════════════════════════════════════════════
#  Prebuild（移植 build.ps1）
# ══════════════════════════════════════════════════════════════════


def prebuild(platform: str) -> dict:
    step("Prebuild（移植 build.ps1）")

    lines = pubspec_read().splitlines()
    version_name = None
    idx = None
    for i, line in enumerate(lines):
        m = re.match(r"^\s*version:\s*([\d.]+)", line)
        if m:
            version_name = m.group(1)
            idx = i
            break

    if version_name is None:
        err("pubspec.yaml 中未找到 version 字段")
        sys.exit(1)

    version_code_str = git_out(["rev-list", "--count", "HEAD"])
    version_code = int(version_code_str) if version_code_str.isdigit() else 0
    commit_hash = git_out(["rev-parse", "HEAD"]) or "unknown"

    display = version_name
    if platform == "android":
        display = f"{version_name}-{commit_hash[:9]}"

    version_full = f"{display}+{version_code}"
    lines[idx] = f"version: {version_full}"
    Path("pubspec.yaml").write_text("\n".join(lines) + "\n", encoding="utf-8")
    ok(f"pubspec.yaml version → {version_full}")

    Path("pili_release.json").write_text(
        json.dumps(
            {
                "pili.name": display,
                "pili.code": version_code,
                "pili.hash": commit_hash,
                "pili.time": int(time.time()),
            },
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    ok("pili_release.json 已生成")
    return {
        "version_name": display,
        "version_code": version_code,
        "version_full": version_full,
    }


# ══════════════════════════════════════════════════════════════════
#  包名替换
#  ① sed patch  — pubspec name 字段 + Dart import 路径
#  ② rename CLI — Android applicationId / iOS Bundle ID / 显示名
# ══════════════════════════════════════════════════════════════════


def _sed_files(old: str, new: str, globs: list):
    import glob as _glob

    for pat in globs:
        for f in _glob.glob(pat, recursive=True):
            p = Path(f)
            if not p.is_file():
                continue
            try:
                content = p.read_text(encoding="utf-8")
                if old in content:
                    p.write_text(content.replace(old, new), encoding="utf-8")
                    info(f"  sed: {f}")
            except Exception as e:
                warn(f"  跳过 {f}: {e}")


def sed_rename(args):
    """
    sed 负责：
      • pubspec.yaml  name: 字段
      • Dart 文件中  package:old_name/ → package:new_name/
      • 原生代码中   com/old/pkg 目录路径形式
      • 仓库 URL    github.com/old/repo → github.com/new/repo
    rename CLI 负责：
      • Android applicationId（build.gradle / AndroidManifest）
      • iOS/macOS Bundle Identifier（plist / pbxproj）
      • 显示名（android:label / CFBundleDisplayName）
    """
    orig_name = args.original_app_name
    new_name = args.app_name
    orig_pkg = args.original_pkg_id
    new_pkg = args.pkg_id

    dart_globs = ["**/*.dart", "pubspec.yaml"]
    native_globs = [
        "android/**/*.kt",
        "android/**/*.java",
        "android/**/*.xml",
        "android/**/*.gradle",
        "android/**/*.gradle.kts",
        "android/**/*.properties",
        "ios/**/*.plist",
        "ios/**/*.pbxproj",
        "macos/**/*.plist",
        "macos/**/*.pbxproj",
        "linux/**/*.cmake",
        "linux/**/*.cc",
        "windows/runner/*.rc",
        "windows/runner/*.h",
        "windows/runner/*.cpp",
        "windows/CMakeLists.txt",
        "assets/linux/com.example.piliplus.desktop",
        "assets/linux/DEBIAN/*",
    ]

    if new_name and orig_name and new_name != orig_name:
        step(f"sed patch: pubspec name  {orig_name} → {new_name}")
        # Dart import 路径
        _sed_files(f"package:{orig_name}/", f"package:{new_name}/", dart_globs)
        # pubspec.yaml name: 字段
        content = pubspec_read()
        content = re.sub(
            r"^(name:\s+)" + re.escape(orig_name),
            r"\g<1>" + new_name,
            content,
            flags=re.MULTILINE,
        )
        Path("pubspec.yaml").write_text(content, encoding="utf-8")
        ok("pubspec.yaml name 字段已更新")

    if new_pkg and orig_pkg and new_pkg != orig_pkg:
        old_path = orig_pkg.replace(".", "/")
        new_path = new_pkg.replace(".", "/")
        if old_path != new_path:
            step(f"sed patch: 包路径  {old_path} → {new_path}")
            _sed_files(old_path, new_path, native_globs)

    # ── 仓库 URL 替换 ──
    if args.repo and args.original_repo and args.repo != args.original_repo:
        step(f"sed patch: 仓库 URL  {args.original_repo} → {args.repo}")
        repo_globs = [
            "assets/linux/DEBIAN/*",
            "lib/**/*.dart",
            "windows/packaging/exe/make_config.yaml",
        ]
        _sed_files(args.original_repo, args.repo, repo_globs)


def rename_cli(args):
    if not args.pkg_id and not args.app_name:
        return
    step("rename CLI（Bundle ID / 显示名）")
    need("rename", "请先运行：dart pub global activate rename")
    if args.pkg_id:
        info(f"setBundleId → {args.pkg_id}")
        run(["rename", "setBundleId", "--value", args.pkg_id])
    if args.app_name:
        info(f"setAppName → {args.app_name}")
        run(["rename", "setAppName", "--value", args.app_name])


def do_rename(args):
    if args.skip_rename:
        return
    sed_rename(args)
    rename_cli(args)

# ══════════════════════════════════════════════════════════════════
#  Git Tools
# ══════════════════════════════════════════════════════════════════

def git_revert(commit_hash: str, 
               cwd: str = None , 
               finished_message: str = "已回滚", 
               bad_message: str = "回滚失败"
               ):
    try:
        run(["git", "config", "user.name", "ci"],cwd=cwd)
        run(["git", "config", "user.email", "ci@example.com"],cwd=cwd)
        run(["git", "stash"],cwd=cwd, check=False)
        run(["git", "revert", commit_hash, "--no-edit"],cwd=cwd)
        run(["git", "stash", "pop"], cwd=cwd, check=False)
        ok(finished_message)
    except subprocess.CalledProcessError:
        warn(bad_message)
       
def git_cherry_pick(commit_hash: str, 
                    cwd: str = None, 
                    finished_message: str = "已应用 cherry-pick", 
                    bad_message: str = "应用 cherry-pick 失败"
                    ):
    try:
        run(["git", "config", "user.name", "ci"],cwd=cwd)
        run(["git", "config", "user.email", "ci@example.com"],cwd=cwd)
        run(["git", "stash"],cwd=cwd, check=False)
        run(["git", "cherry-pick", commit_hash, "--no-edit"],cwd=cwd)
        run(["git", "reset", "--soft", "HEAD~1"],cwd=cwd)
        run(["git", "stash", "pop"], cwd=cwd, check=False)
        ok(finished_message)
    except subprocess.CalledProcessError:
        warn(bad_message)
        
def git_patch(patch_file: str | Path, 
              cwd: str = None, 
              notfound_message: str = "patch 不存在，跳过",
              finished_message: str = "已应用 patch", 
              bad_message: str = "应用 patch 失败"
            ):
    patch_file = Path(patch_file).resolve()
    if not patch_file.exists():
        warn(notfound_message)
        return
    try:
        run(["git", "apply", str(patch_file), "--ignore-whitespace"], cwd=cwd)
        ok(finished_message)
    except subprocess.CalledProcessError:
        warn(bad_message)

# ══════════════════════════════════════════════════════════════════
#  Flutter patches & pub get
# ══════════════════════════════════════════════════════════════════


def flutter_root():
    w = shutil.which("flutter")
    return str(Path(w).parent.parent) if w else None


def apply_patches(root: str, platform: str = ""):
    step("应用 Flutter patches")

    # Android 专属：revert overscroll indicator（https://github.com/flutter/flutter/issues/182281）
    if platform == "android":
        REVERT_HASH = "362b1de29974ffc1ed6faa826e1df870d7bec75f"
        step(f"revert overscroll indicator commit ({REVERT_HASH[:9]}…)")
        git_revert(REVERT_HASH, 
                   cwd=root, 
                   finished_message="overscroll indicator revert 完成", 
                   bad_message="overscroll indicator revert 失败（已忽略）"
                   )
    
    if platform in ["linux","macos","windows"]:
        CHECKOUT_HASH = "56956c33ef102ac0b5fc46b62bd2dd9f50a86616"
        step(f"checkout Add RawTooltip.ignorePointer commit ({CHECKOUT_HASH[:9]}…)")
        git_cherry_pick(CHECKOUT_HASH, 
                        cwd=root, 
                        finished_message="Add RawTooltip.ignorePointer 应用完成", 
                        bad_message="Add RawTooltip.ignorePointer 应用失败（已忽略）"
                        )

    for name in [
        "bottom_sheet_patch.diff",
        "modal_barrier_patch.diff",
        "mouse_cursor_patch.diff",
    ]:
        p = Path("lib/scripts") / name
        git_patch(p, 
                    cwd=root, 
                    notfound_message=f"patch 不存在，跳过: {name}",
                    finished_message=f"Patch OK: {name}",
                    bad_message=f"Patch 应用失败（已忽略）: {name}"
                )


def common_setup(args):
    root = flutter_root()
    if args.apply_patches and root:
        apply_patches(root, platform=args.platform)
    if not args.no_pub_get:
        step("flutter pub get")
        run(["flutter", "pub", "get"])
    return root


# ══════════════════════════════════════════════════════════════════
#  构建参数组装
# ══════════════════════════════════════════════════════════════════


def dart_defs(args) -> list:
    r = []
    if args.dart_define_from_file and Path(args.dart_define_from_file).exists():
        r += ["--dart-define-from-file", args.dart_define_from_file]
    for d in args.dart_define or []:
        r += ["--dart-define", d]
    return r


def odir(args) -> Path:
    p = Path(args.output)
    p.mkdir(parents=True, exist_ok=True)
    return p


# ══════════════════════════════════════════════════════════════════
#  Android 签名
# ══════════════════════════════════════════════════════════════════


def setup_signing(args) -> bool:
    if not args.sign:
        return False
    step("配置 Android 签名")

    key_jks = Path("android/app/key.jks")
    key_prop = Path("android/key.properties")

    if args.keystore_base64:
        import base64

        key_jks.write_bytes(base64.b64decode(args.keystore_base64))
        ok("keystore 已从 base64 写入")
    elif args.keystore_file:
        shutil.copy2(args.keystore_file, key_jks)
        ok(f"keystore 已复制: {args.keystore_file}")
    elif key_jks.exists():
        ok("使用已有 android/app/key.jks")
    else:
        warn("--sign 已设置，但无 keystore，将用 debug 签名")
        return False

    if not args.key_alias:
        err("签名需要 --key-alias")
        sys.exit(1)
    if not args.key_password:
        err("签名需要 --key-password")
        sys.exit(1)

    key_prop.write_text(
        f"storeFile=key.jks\nstorePassword={args.store_password or args.key_password}\n"
        f"keyAlias={args.key_alias}\nkeyPassword={args.key_password}\n",
        encoding="utf-8",
    )
    ok("android/key.properties 已写入")
    return True


def cleanup_keys():
    for p in [Path("android/app/key.jks"), Path("android/key.properties")]:
        if p.exists():
            p.unlink()
            info(f"已清理: {p}")


# ══════════════════════════════════════════════════════════════════
#  Android
# ══════════════════════════════════════════════════════════════════


def build_android(args, vi: dict):
    step("构建 Android")
    signed = setup_signing(args)
    try:
        run(
            [
                "flutter",
                "build",
                "apk",
                "--release",
                "--pub",
                *([] if args.no_split else ["--split-per-abi"]),
                *dart_defs(args),
                *(args.extra_build_args or []),
            ]
        )
    finally:
        if signed and args.clean_keys:
            cleanup_keys()

    step("重命名 APK")
    apk_dir = Path("build/app/outputs/flutter-apk")
    o = odir(args)
    apks = list(apk_dir.glob("app-*-release.apk")) or list(
        apk_dir.glob("app-release.apk")
    )
    for apk in apks:
        m = re.search(r"app-(.+)-release\.apk", apk.name)
        abi = m.group(1) if m else "universal"
        dst = o / f"{args.output_prefix}_android_{vi['version_full']}_{abi}.apk"
        shutil.copy2(apk, dst)
        ok(f"输出: {dst}")


# ══════════════════════════════════════════════════════════════════
#  iOS
# ══════════════════════════════════════════════════════════════════


def build_ios(args, vi: dict):
    if _sys_platform.system() != "Darwin":
        err("iOS 构建只能在 macOS")
        sys.exit(1)
    step("构建 iOS")
    run(
        [
            "flutter",
            "build",
            "ios",
            "--release",
            "--no-codesign",
            *dart_defs(args),
            *(args.extra_build_args or []),
        ]
    )

    step("打包 IPA")
    ipa = f"{args.output_prefix}_ios_{vi['version_full']}.ipa"
    payload = Path("Payload")
    if payload.is_symlink() or payload.exists():
        payload.unlink() if payload.is_symlink() else shutil.rmtree(payload)
    payload.symlink_to("build/ios/iphoneos")
    sh(
        'find Payload/Runner.app/Frameworks -type d -name "*.framework" '
        "-exec codesign --force --sign - --preserve-metadata=identifier,entitlements {} \\;",
        check=False,
    )
    sh(f"zip -r9 {ipa} Payload/Runner.app")
    shutil.move(ipa, odir(args) / ipa)
    ok(f"输出: {odir(args) / ipa}")


# ══════════════════════════════════════════════════════════════════
#  macOS
# ══════════════════════════════════════════════════════════════════


def build_macos(args, vi: dict):
    if _sys_platform.system() != "Darwin":
        err("macOS 构建只能在 macOS")
        sys.exit(1)
    step("构建 macOS")
    run(
        [
            "flutter",
            "build",
            "macos",
            "--release",
            *dart_defs(args),
            *(args.extra_build_args or []),
        ]
    )

    app = next(Path("build/macos/Build/Products/Release").glob("*.app"), None)
    if not app:
        err("未找到 .app")
        sys.exit(1)

    o = odir(args)
    if shutil.which("create-dmg"):
        sh(f'create-dmg "{app}" || true', check=False)
        dmgs = list(Path(".").glob("*.dmg"))
        if dmgs:
            dst = o / f"{args.output_prefix}_macos_{vi['version_full']}.dmg"
            shutil.move(str(dmgs[0]), dst)
            ok(f"输出: {dst}")
            return
    warn("create-dmg 未安装，fallback zip。npm i -g create-dmg")
    dst = o / f"{args.output_prefix}_macos_{vi['version_full']}.zip"
    sh(f'zip -r9 "{dst}" "{app}"')
    ok(f"输出（zip）: {dst}")


# ══════════════════════════════════════════════════════════════════
#  Windows
# ══════════════════════════════════════════════════════════════════


def build_windows(args, vi: dict):
    step("构建 Windows")
    o = odir(args)
    prefix = args.output_prefix
    version = vi["version_full"]

    if args.installer and shutil.which("fastforge"):
        dfs = (
            f"dart-define-from-file={args.dart_define_from_file}"
            if args.dart_define_from_file and Path(args.dart_define_from_file).exists()
            else ""
        )
        run(
            [
                "fastforge",
                "package",
                "--platform",
                "windows",
                "--targets",
                "exe",
                *(["--flutter-build-args", dfs] if dfs else []),
                *(args.extra_build_args or []),
            ]
        )
        for exe in Path("dist").rglob("*.exe"):
            dst = o / f"{prefix}_windows_{version}_x64_setup.exe"
            shutil.copy2(exe, dst)
            ok(f"输出 (installer): {dst}")
    else:
        if args.installer:
            warn("fastforge 未找到，跳过 installer")
        run(
            [
                "flutter",
                "build",
                "windows",
                "--release",
                *dart_defs(args),
                *(args.extra_build_args or []),
            ]
        )

    bundle = Path("build/windows/x64/runner/Release")
    if bundle.exists():
        base = o / f"{prefix}_windows_{version}_x64_portable"
        shutil.make_archive(str(base), "zip", bundle)
        ok(f"输出 (portable): {base}.zip")


# ══════════════════════════════════════════════════════════════════
#  Linux 各打包格式
# ══════════════════════════════════════════════════════════════════


def _pkg_name(args) -> str:
    return args.app_name or pubspec_name()


def _tar_gz(prefix, version, arch, bundle, o):
    out = o / f"{prefix}_linux_{version}_{arch}.tar.gz"
    sh(f"tar -zcf {out} -C {bundle} .")
    ok(f"输出: {out}")


def _tar_zst(prefix, version, arch, bundle, o):
    """标准 tar.zst，与 pacman 兼容的压缩格式（注意：不含 PKGINFO，不可 pacman -U）"""
    need("zstd", "sudo pacman -S zstd  /  sudo apt install zstd")
    out = o / f"{prefix}_linux_{version}_{arch}.tar.zst"
    sh(f"tar --use-compress-program='zstd -19 -T0' -cf {out} -C {bundle} .")
    ok(f"输出: {out}")


def _arch_pkg(prefix, version, arch, bundle, o, args):
    """
    生成正规 Arch Linux .pkg.tar.zst
    含 .PKGINFO / .MTREE，可直接 pacman -U 安装。
    原理：生成 PKGBUILD + 预构建 bundle source tarball，
    用 makepkg 打包（不重新编译 Flutter）。
    """
    step("打包 Arch Linux .pkg.tar.zst（makepkg）")
    need("makepkg", "请在 Arch Linux 系统上运行")

    app_name = _pkg_name(args)
    # pacman 版本号不能含 + -，转成 _
    pkg_ver = re.sub(r"[+\-]", "_", version)
    pkg_arch = "x86_64" if arch == "x64" else arch

    work = Path(f"/tmp/{prefix}_arch_build")
    if work.exists():
        shutil.rmtree(work)
    work.mkdir(parents=True)

    # ── 把 bundle 打成 source tarball（makepkg 需要 source 文件）──
    src_name = f"{app_name}-{pkg_ver}"
    src_dir = work / src_name
    src_dir.mkdir()
    shutil.copytree(bundle, src_dir / "bundle", dirs_exist_ok=True)

    desktop = (
        next(Path("assets/linux").glob("*.desktop"), None)
        if Path("assets/linux").exists()
        else None
    )
    logo = Path("assets/images/logo/logo.png")
    if desktop:
        shutil.copy2(desktop, src_dir / desktop.name)
    if logo.exists():
        shutil.copy2(logo, src_dir / f"{app_name}.png")

    src_tar = work / f"{src_name}.tar.gz"
    sh(f"tar -zcf {src_tar} -C {work} {src_name}")
    sha256 = sh(f"sha256sum {src_tar}", capture=True).stdout.split()[0]

    desktop_name = desktop.name if desktop else f"com.example.{app_name}.desktop"

    # ── 写 PKGBUILD ──
    (work / "PKGBUILD").write_text(
        textwrap.dedent(f"""\
        # Maintainer: auto-generated by build.py
        pkgname={app_name}
        pkgver={pkg_ver}
        pkgrel=1
        pkgdesc="Flutter App"
        arch=('{pkg_arch}')
        url="https://github.com"
        license=('GPL-3.0-or-later')
        depends=('gtk3' 'libayatana-appindicator' 'mpv')
        source=("{src_name}.tar.gz")
        sha256sums=('{sha256}')

        package() {{
            cd "$srcdir/{src_name}"

            # 主体文件
            install -dm755 "$pkgdir/opt/{app_name}"
            cp -rdp --no-preserve=ownership bundle/. "$pkgdir/opt/{app_name}/"
            chmod 755 "$pkgdir/opt/{app_name}/{app_name}"

            # 启动脚本（处理 LD_LIBRARY_PATH，Arch 需要）
            install -dm755 "$pkgdir/usr/bin"
            cat > "$pkgdir/usr/bin/{app_name}" << 'LAUNCHER'
        #!/bin/bash
        LD_LIBRARY_PATH="/opt/{app_name}/lib:$LD_LIBRARY_PATH" exec "/opt/{app_name}/{app_name}" "$@"
        LAUNCHER
            chmod 755 "$pkgdir/usr/bin/{app_name}"

            # 桌面文件
            install -dm755 "$pkgdir/usr/share/applications"
            [[ -f {desktop_name} ]] && install -Dm644 {desktop_name} \\
                "$pkgdir/usr/share/applications/{desktop_name}"

            # 图标
            install -dm755 "$pkgdir/usr/share/icons/hicolor/512x512/apps"
            [[ -f {app_name}.png ]] && install -Dm644 {app_name}.png \\
                "$pkgdir/usr/share/icons/hicolor/512x512/apps/{app_name}.png"
        }}
    """),
        encoding="utf-8",
    )

    # ── 运行 makepkg ──
    sh(
        "makepkg -f --noconfirm",
        cwd=work,
        env={
            **os.environ,
            "PKGDEST": str(o.resolve()),
            "PACKAGER": "build.py <local>",
            "SRCDEST": str(work),
        },
    )

    shutil.rmtree(work, ignore_errors=True)
    for p in o.glob(f"{app_name}-{pkg_ver}*.pkg.tar.zst"):
        ok(f"输出: {p}")


def _deb(prefix, version, arch, bundle, o, args):
    step("打包 deb")
    need("dpkg-deb")
    app_name = _pkg_name(args)
    root = Path(f"/tmp/{prefix}_deb")
    if root.exists():
        shutil.rmtree(root)

    for d in [
        "opt/app",
        "usr/share/applications",
        "usr/share/icons/hicolor/512x512/apps",
    ]:
        (root / d).mkdir(parents=True)

    shutil.copytree(bundle, root / "opt/app", dirs_exist_ok=True)

    ctrl_src = Path("assets/linux/DEBIAN")
    (root / "DEBIAN").mkdir(exist_ok=True)
    if ctrl_src.exists():
        shutil.copytree(ctrl_src, root / "DEBIAN", dirs_exist_ok=True)
        ctrl = root / "DEBIAN/control"
        if ctrl.exists():
            txt = ctrl.read_text()
            txt = txt.replace("version_need_change", version)
            size_kb = (
                sum(
                    f.stat().st_size
                    for f in (root / "opt/app").rglob("*")
                    if f.is_file()
                )
                // 1024
                + 1
            )
            txt = txt.replace("size_need_change", str(size_kb))
            ctrl.write_text(txt, encoding="utf-8")
        for s in ["postinst", "postrm", "prerm"]:
            sp = root / "DEBIAN" / s
            if sp.exists():
                sp.chmod(0o755)
    else:
        (root / "DEBIAN/control").write_text(
            f"Package: {app_name}\nVersion: {version}\nArchitecture: amd64\n"
            f"Maintainer: Unknown\nInstalled-Size: 0\nDescription: Flutter App\n"
        )

    desktop = (
        next(Path("assets/linux").glob("*.desktop"), None)
        if Path("assets/linux").exists()
        else None
    )
    if desktop:
        shutil.copy2(desktop, root / "usr/share/applications" / desktop.name)
    logo = Path("assets/images/logo/logo.png")
    if logo.exists():
        shutil.copy2(
            logo, root / f"usr/share/icons/hicolor/512x512/apps/{app_name}.png"
        )

    out = o / f"{prefix}_linux_{version}_{arch}.deb"
    sh(f"dpkg-deb --build --verbose --root-owner-group {root} {out}")
    shutil.rmtree(root, ignore_errors=True)
    ok(f"输出: {out}")


def _rpm(prefix, version, arch, bundle, o, args):
    step("打包 rpm")
    need("rpmbuild", "sudo apt install rpm-build  /  sudo dnf install rpm-build")
    import datetime

    app_name = _pkg_name(args)
    rpm_ver = re.sub(r"[+\-]", "_", version)
    rpm_root = Path(f"/tmp/{prefix}_rpm")
    for d in ["BUILD", "RPMS", "SOURCES", "SPECS", "SRPMS"]:
        (rpm_root / d).mkdir(parents=True, exist_ok=True)

    src_dir = rpm_root / f"{app_name}-{rpm_ver}"
    src_dir.mkdir()
    (src_dir / "bundle").mkdir()
    (src_dir / "assets").mkdir()
    shutil.copytree(bundle, src_dir / "bundle", dirs_exist_ok=True)

    desktop = (
        next(Path("assets/linux").glob("*.desktop"), None)
        if Path("assets/linux").exists()
        else None
    )
    logo = Path("assets/images/logo/logo.png")
    if desktop:
        shutil.copy2(desktop, src_dir / "assets" / desktop.name)
    if logo.exists():
        shutil.copy2(logo, src_dir / f"assets/{app_name}.png")

    sh(
        f"tar -zcf {rpm_root}/SOURCES/{app_name}-{rpm_ver}.tar.gz "
        f"-C {rpm_root} {app_name}-{rpm_ver}"
    )

    desktop_name = desktop.name if desktop else f"com.example.{app_name}.desktop"
    date_str = datetime.datetime.now().strftime("%a %b %d %Y")

    (rpm_root / f"SPECS/{app_name}.spec").write_text(
        textwrap.dedent(f"""\
        Name:           {app_name}
        Version:        {rpm_ver}
        Release:        1%{{?dist}}
        Summary:        Flutter App
        License:        GPL-3.0
        Source0:        {app_name}-{rpm_ver}.tar.gz
        Requires:       desktop-file-utils, hicolor-icon-theme

        %description
        Flutter App

        %prep
        %setup -q -n {app_name}-{rpm_ver}

        %build

        %install
        mkdir -p %{{buildroot}}/opt/{app_name}
        cp -r bundle/* %{{buildroot}}/opt/{app_name}/
        chmod 755 %{{buildroot}}/opt/{app_name}/{app_name}
        mkdir -p %{{buildroot}}/usr/bin
        ln -sf /opt/{app_name}/{app_name} %{{buildroot}}/usr/bin/{app_name}
        mkdir -p %{{buildroot}}/usr/share/applications
        install -m 644 assets/{desktop_name} \\
            %{{buildroot}}/usr/share/applications/{desktop_name}
        mkdir -p %{{buildroot}}/usr/share/icons/hicolor/512x512/apps
        install -m 644 assets/{app_name}.png \\
            %{{buildroot}}/usr/share/icons/hicolor/512x512/apps/{app_name}.png

        %post
        update-desktop-database -q || true
        gtk-update-icon-cache -q -t -f %{{_datadir}}/icons/hicolor || true

        %postun
        update-desktop-database -q || true
        gtk-update-icon-cache -q -t -f %{{_datadir}}/icons/hicolor || true

        %files
        /opt/{app_name}
        /usr/bin/{app_name}
        /usr/share/applications/{desktop_name}
        /usr/share/icons/hicolor/512x512/apps/{app_name}.png

        %changelog
        * {date_str} - {rpm_ver}-1
        - Build
    """),
        encoding="utf-8",
    )

    sh(f"rpmbuild --define '_topdir {rpm_root}' -bb {rpm_root}/SPECS/{app_name}.spec")

    for rpm_file in (rpm_root / "RPMS").rglob("*.rpm"):
        dst = o / f"{prefix}_linux_{version}_{arch}.rpm"
        shutil.move(str(rpm_file), dst)
        ok(f"输出: {dst}")

    shutil.rmtree(rpm_root, ignore_errors=True)


def _appimage(prefix, version, arch, bundle, o, args):
    step("打包 AppImage")
    app_name = _pkg_name(args)
    tool = Path("appimagetool-x86_64.AppImage")
    if not tool.exists():
        sh(
            "wget -q https://github.com/AppImage/appimagetool/releases/"
            "download/continuous/appimagetool-x86_64.AppImage"
        )
        tool.chmod(0o755)

    appdir = Path(f"/tmp/{prefix}.AppDir")
    if appdir.exists():
        shutil.rmtree(appdir)
    for d in [
        "usr/bin",
        "usr/lib",
        "usr/share/applications",
        "usr/share/icons/hicolor/512x512/apps",
    ]:
        (appdir / d).mkdir(parents=True)

    shutil.copytree(bundle, appdir / "usr/bin", dirs_exist_ok=True)

    desktop = (
        next(Path("assets/linux").glob("*.desktop"), None)
        if Path("assets/linux").exists()
        else None
    )
    logo = Path("assets/images/logo/logo.png")
    if desktop:
        shutil.copy2(desktop, appdir / desktop.name)
        shutil.copy2(desktop, appdir / "usr/share/applications" / desktop.name)
    if logo.exists():
        shutil.copy2(logo, appdir / f"{app_name}.png")
        shutil.copy2(
            logo, appdir / f"usr/share/icons/hicolor/512x512/apps/{app_name}.png"
        )

    (appdir / "AppRun").write_text(
        '#!/bin/bash\nSELF=$(readlink -f "$0")\nHERE=${SELF%/*}\n'
        'export PATH="${HERE}/usr/bin:${PATH}"\n'
        'export LD_LIBRARY_PATH="${HERE}/usr/lib:${LD_LIBRARY_PATH}"\n'
        f'exec "${{HERE}}/usr/bin/{app_name}" "$@"\n'
    )
    (appdir / "AppRun").chmod(0o755)

    out = o / f"{prefix}_linux_{version}_{arch}.AppImage"
    sh(f"ARCH=x86_64 ./{tool} {appdir} {out}")
    shutil.rmtree(appdir, ignore_errors=True)
    ok(f"输出: {out}")


# ══════════════════════════════════════════════════════════════════
#  Linux 入口
# ══════════════════════════════════════════════════════════════════


def build_linux(args, vi: dict):
    if _sys_platform.system() != "Linux":
        err("Linux 构建只能在 Linux")
        sys.exit(1)
    step("构建 Linux")

    arch = args.arch or "x64"
    prefix = args.output_prefix
    version = vi["version_full"]
    o = odir(args)

    run(
        [
            "flutter",
            "build",
            "linux",
            "--release",
            *dart_defs(args),
            *(args.extra_build_args or []),
        ]
    )

    bundle = Path(f"build/linux/{arch}/release/bundle")
    if not bundle.exists():
        err(f"未找到构建产物: {bundle}")
        sys.exit(1)

    targets = set(args.linux_targets or ["tar.gz"])
    if "all" in targets:
        targets = {"tar.gz", "zst", "arch", "deb", "rpm", "appimage"}

    dispatch = {
        "tar.gz": lambda: _tar_gz(prefix, version, arch, bundle, o),
        "zst": lambda: _tar_zst(prefix, version, arch, bundle, o),
        "arch": lambda: _arch_pkg(prefix, version, arch, bundle, o, args),
        "deb": lambda: _deb(prefix, version, arch, bundle, o, args),
        "rpm": lambda: _rpm(prefix, version, arch, bundle, o, args),
        "appimage": lambda: _appimage(prefix, version, arch, bundle, o, args),
    }

    for t in targets:
        if t not in dispatch:
            warn(f"未知打包目标: {t}")
            continue
        try:
            dispatch[t]()
        except Exception as e:
            warn(f"{t} 打包失败: {e}（已跳过）")


# ══════════════════════════════════════════════════════════════════
#  参数解析
# ══════════════════════════════════════════════════════════════════


def parse_args():
    p = argparse.ArgumentParser(
        description="Flutter 多平台构建脚本",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=__doc__ + """
透传参数:
  --                    之后的所有参数直接传给 flutter build，例如:
                          python build.py android -- --obfuscate --split-debug-info=./debug
""",
    )
    p.add_argument(
        "platform", choices=["android", "ios", "macos", "windows", "linux", "all"]
    )

    g = p.add_argument_group("包名替换")
    g.add_argument(
        "--pkg-id",
        metavar="ID",
        default="com.pili.super",
        help="新 Bundle ID，如 com.myfork.app",
    )
    g.add_argument(
        "--original-pkg-id",
        metavar="ID",
        default="com.example.piliplus",
        help="上游 applicationId（默认: com.example.piliplus）",
    )
    g.add_argument(
        "--app-name",
        metavar="NAME",
        default="PiliSuper",
        help="新 pubspec name / 显示名",
    )
    g.add_argument(
        "--original-app-name",
        metavar="NAME",
        default="PiliPlus",
        help="上游 pubspec name（默认: piliPlus）",
    )
    g.add_argument("--skip-rename", action="store_true")
    g.add_argument(
        "--repo",
        metavar="USER/REPO",
        default="FRBLanApps/PiliSuper",
        help="新仓库路径（默认: FRBLanApps/PiliSuper）",
    )
    g.add_argument(
        "--original-repo",
        metavar="USER/REPO",
        default="bggRGjQaUbCoE/PiliPlus",
        help="上游仓库路径（默认: bggRGjQaUbCoE/PiliPlus）",
    )

    g = p.add_argument_group("构建参数")
    g.add_argument(
        "--dart-define-from-file", default="pili_release.json", metavar="FILE"
    )
    g.add_argument("--dart-define", action="append", default=[], metavar="K=V")
    g.add_argument("--arch", default=None)
    g.add_argument("--version", default=None, help="手动版本号，跳过 prebuild 计算")
    g.add_argument("--no-prebuild", action="store_true")

    g = p.add_argument_group("Android")
    g.add_argument("--no-split", action="store_true")

    g = p.add_argument_group("Android 签名")
    g.add_argument("--sign", action="store_true")
    g.add_argument("--keystore-file", metavar="PATH")
    g.add_argument("--keystore-base64", metavar="B64")
    g.add_argument("--key-alias", metavar="ALIAS")
    g.add_argument("--key-password", metavar="PASS")
    g.add_argument("--store-password", metavar="PASS")
    g.add_argument(
        "--clean-keys",
        action="store_true",
        help="构建后删除 key.jks / key.properties（CI 用）",
    )

    g = p.add_argument_group("Windows")
    g.add_argument("--installer", action="store_true")

    g = p.add_argument_group("Linux")
    g.add_argument(
        "--linux-targets",
        nargs="+",
        default=["tar.gz"],
        choices=["tar.gz", "zst", "arch", "deb", "rpm", "appimage", "all"],
        help="打包格式。arch = 正规 .pkg.tar.zst（需要 makepkg）；"
        "zst = 仅压缩的 tar.zst（不可 pacman -U）",
    )

    g = p.add_argument_group("通用")
    g.add_argument("--output", "-o", default="dist", metavar="DIR")
    g.add_argument("--output-prefix", default="PiliSuper", metavar="PREFIX")
    g.add_argument(
        "--no-patches", dest="apply_patches", action="store_false", default=True
    )
    g.add_argument("--no-pub-get", action="store_true")

    args, unknown = p.parse_known_args()

    # 透传给 flutter build 的参数：只收集 -- 之后的内容，其余 unknown 报警
    try:
        sep = sys.argv.index("--")
        args.extra_build_args = sys.argv[sep + 1 :]
    except ValueError:
        args.extra_build_args = []
        if unknown:
            warn(f"未知参数（已忽略）: {unknown}")

    if not args.output_prefix and Path("pubspec.yaml").exists():
        args.output_prefix = pubspec_name()

    return args


# ══════════════════════════════════════════════════════════════════
#  入口
# ══════════════════════════════════════════════════════════════════


def main():
    if not Path("pubspec.yaml").exists():
        err("请在 Flutter 项目根目录运行（找不到 pubspec.yaml）")
        sys.exit(1)

    args = parse_args()

    # 1. 包名替换（sed + rename CLI）
    do_rename(args)

    # 2. Prebuild（版本号 + pili_release.json）
    if args.no_prebuild:
        v = args.version or pubspec_version_base()
        vi = {"version_name": v, "version_code": 0, "version_full": v}
    else:
        plat = args.platform if args.platform != "all" else "other"
        vi = prebuild(plat)
        if args.version:
            vi["version_full"] = args.version

    info(f"版本: {vi['version_full']}")

    # 3. pub get + patches
    common_setup(args)

    # 4. 构建
    builders = {
        "android": build_android,
        "ios": build_ios,
        "macos": build_macos,
        "windows": build_windows,
        "linux": build_linux,
    }
    platforms = list(builders) if args.platform == "all" else [args.platform]

    for plat in platforms:
        try:
            builders[plat](args, vi)
        except subprocess.CalledProcessError as e:
            err(f"{plat} 构建失败: {e}")
            if args.platform != "all":
                sys.exit(1)
        except SystemExit:
            raise
        except Exception as e:
            err(f"{plat} 异常: {e}")
            raise

    ok(f"完成！输出: {args.output}/")


if __name__ == "__main__":
    main()
