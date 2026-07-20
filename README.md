<div align="center">
    <img width="200" height="200" src="assets/images/logo/logo.png">
</div>

<div align="center">
    <h1>PiliSuper</h1>
    <p>使用 Flutter 开发的 BiliBili 第三方客户端</p>
</div>

## 编译

安装 [Flutter](https://docs.flutter.dev/install/custom)、Python 和目标平台所需的原生工具链后，在仓库根目录执行。依赖解析是显式步骤：首次构建或修改 `pubspec.yaml` 后运行一次：

```sh
flutter pub get
```

构建流程由小脚本组成；每个脚本只做一件事，不存在总控 `build.py`。

| 脚本 | 职责 |
| --- | --- |
| `rename.py` | 改 Bundle ID、显示名、Dart 包名和仓库引用 |
| `prebuild.py` | 生成 `pili_release.json` 并写入 Git 版本号 |
| `patch.py` | 为指定平台应用 Flutter SDK 补丁 |
| `build_android.py` | 构建并导出 Android APK |
| `build_ios.py` | 构建未签名 IPA |
| `build_macos.py` | 构建 macOS DMG（或 ZIP） |
| `build_windows.py` | 构建 Windows portable ZIP |
| `build_linux.py` | 仅构建 Linux bundle |
| `packaging.py` | 仅把已有 Linux bundle 打包为 tar.gz、tar.zst 或 deb |

例如，构建 Android release：

```sh
python rename.py --pkg-id com.pili.super --app-name PiliSuper
python prebuild.py --platform android
VERSION=$(sed -n 's/^version: //p' pubspec.yaml)
python patch.py android
python build_android.py --version "$VERSION" --output dist
```

Linux 构建和打包分开：

```sh
python prebuild.py --platform linux
VERSION=$(sed -n 's/^version: //p' pubspec.yaml)
python patch.py linux
python build_linux.py
python packaging.py --version "$VERSION" tar.gz deb
```

所有 Flutter 构建脚本都传入 `--no-pub`，因此不会隐式执行 `flutter pub get`。

## 声明

此项目（PiliSuper）是个人为了兴趣而开发，仅用于学习和测试；请按照当地法律使用。

致敬原作者：[bggRGjQaUbCoE/PiliPlus](https://github.com/bggRGjQaUbCoE/PiliPlus)。
