import 'dart:io';
import 'dart:typed_data';

import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/export/export_channel.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

/// 导出文件所在的子目录名，各平台一致。
const String exportSubDir = 'PiliSuper';

/// 当前导出位置。启动时由 [initExportTarget] 赋值。
late ExportTarget exportTarget;

/// [exportTarget] 的展示文本缓存。
///
/// SAF / MediaStore 的展示路径需要走原生查询，而设置项的副标题是同步取值的，
/// 因此在切换目标时预先算好。
String exportTargetLabel = '';

/// 切换导出位置，并刷新展示文本。
Future<void> setExportTarget(ExportTarget target) async {
  exportTarget = target;
  exportTargetLabel = await target.displayLabel();
}

/// 导出目标。
///
/// 三种实现覆盖了所有平台：
///  - [FsTarget]：普通文件系统路径，桌面端 / iOS / Android API 24~28；
///  - [MediaStoreTarget]：Android API 29+ 默认，落在公共 Download 目录，无需权限；
///  - [SafTreeTarget]：Android 用户自选目录，持久化的 SAF tree uri。
///
/// [encode] / [decode] 负责与设置项里的单个字符串互转，
/// 让 `storage_pref` 不必感知平台差异。
sealed class ExportTarget {
  const ExportTarget();

  static const String _fsPrefix = 'file:';
  static const String _safPrefix = 'saf:';
  static const String _mediaStorePrefix = 'mediastore:';

  /// 从设置值还原。空串或无法识别时返回 `null`，调用方回退到平台默认值。
  static ExportTarget? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    if (raw.startsWith(_fsPrefix)) {
      final dir = raw.substring(_fsPrefix.length);
      return dir.isEmpty ? null : FsTarget(dir);
    }
    if (raw.startsWith(_safPrefix)) {
      final uri = raw.substring(_safPrefix.length);
      return uri.isEmpty ? null : SafTreeTarget(uri);
    }
    if (raw.startsWith(_mediaStorePrefix)) {
      final relativePath = raw.substring(_mediaStorePrefix.length);
      return relativePath.isEmpty ? null : MediaStoreTarget(relativePath);
    }
    // 兼容早期可能写入的裸路径。
    return FsTarget(raw);
  }

  /// 平台默认导出位置。
  ///
  /// `getDownloadsDirectory()` 在 Android/iOS 上返回 `null`，因此两端各自处理：
  /// Android 29+ 用 MediaStore 落到真正的 Download 目录，24~28 直写公共目录，
  /// iOS 用应用 Documents 目录（配合 Info.plist 后可在「文件」里浏览）。
  static Future<ExportTarget> platformDefault() async {
    if (Platform.isAndroid) {
      if (DeviceUtils.sdkInt >= 29) {
        return const MediaStoreTarget('Download/$exportSubDir');
      }
      final publicDir = await ExportChannel.publicDownloadsDir();
      if (publicDir != null && publicDir.isNotEmpty) {
        return FsTarget(path.join(publicDir, exportSubDir));
      }
      return FsTarget(path.join(downloadPath, PathUtils.exportDir));
    }
    if (Platform.isIOS) {
      final docDir = await getApplicationDocumentsDirectory();
      return FsTarget(path.join(docDir.path, exportSubDir));
    }
    String? downloads;
    try {
      downloads = (await getDownloadsDirectory())?.path;
    } catch (_) {
      downloads = null;
    }
    return FsTarget(
      downloads != null && downloads.isNotEmpty
          ? path.join(downloads, exportSubDir)
          : path.join(appSupportDirPath, PathUtils.exportDir),
    );
  }

  /// 是否允许用户改变导出位置。
  ///
  /// iOS 上沙盒外的目录需要 security-scoped bookmark 才能跨启动使用，
  /// 成本远大于收益，因此固定为 Documents 目录。
  static bool get configurable => !Platform.isIOS;

  String encode();

  /// 设置项副标题展示的文本。
  Future<String> displayLabel();

  /// 目标当前是否可写。SAF 授权被撤销、外置存储被移除时返回 `false`。
  Future<bool> isUsable();

  /// 创建一个待写入的输出。
  Future<ExportSink> openSink({
    required String fileName,
    required String mimeType,
  });
}

/// 普通文件系统目录。
final class FsTarget extends ExportTarget {
  const FsTarget(this.dirPath);

  final String dirPath;

  @override
  String encode() => '${ExportTarget._fsPrefix}$dirPath';

  @override
  Future<String> displayLabel() async => dirPath;

  @override
  Future<bool> isUsable() async {
    try {
      if (Directory(dirPath).existsSync()) return true;
      // 目录留到真正导出时再建，避免只是打开设置页就凭空多出空文件夹。
      // 这里只确认祖先目录存在，能创建即视为可用。
      var parent = path.dirname(dirPath);
      while (parent.isNotEmpty && parent != path.dirname(parent)) {
        if (Directory(parent).existsSync()) return true;
        parent = path.dirname(parent);
      }
      return Directory(parent).existsSync();
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ExportSink> openSink({
    required String fileName,
    required String mimeType,
  }) async {
    final dir = Directory(dirPath);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }
    return FsSink(File(_uniquePath(dirPath, fileName)));
  }

  /// 避免静默覆盖已有文件，与 MediaStore / SAF 的自动改名行为保持一致。
  static String _uniquePath(String dirPath, String fileName) {
    final ext = path.extension(fileName);
    final stem = path.basenameWithoutExtension(fileName);
    var candidate = path.join(dirPath, fileName);
    var index = 1;
    while (File(candidate).existsSync()) {
      candidate = path.join(dirPath, '$stem ($index)$ext');
      index++;
    }
    return candidate;
  }
}

/// Android MediaStore Downloads。
final class MediaStoreTarget extends ExportTarget {
  const MediaStoreTarget(this.relativePath);

  /// MediaStore 的 `RELATIVE_PATH`，如 `Download/PiliSuper`。
  final String relativePath;

  @override
  String encode() => '${ExportTarget._mediaStorePrefix}$relativePath';

  @override
  Future<String> displayLabel() async => relativePath;

  @override
  Future<bool> isUsable() async =>
      Platform.isAndroid && DeviceUtils.sdkInt >= 29;

  @override
  Future<ExportSink> openSink({
    required String fileName,
    required String mimeType,
  }) async {
    final uri = await ExportChannel.createInDownloads(
      name: fileName,
      mime: mimeType,
      // MediaStore 要求以 `/` 结尾表示目录。
      relativePath: relativePath.endsWith('/')
          ? relativePath
          : '$relativePath/',
    );
    if (uri == null) {
      throw const ExportChannelException('无法在下载目录创建文件');
    }
    return ContentUriSink(uri, isPending: true);
  }
}

/// Android SAF 目录树。
final class SafTreeTarget extends ExportTarget {
  const SafTreeTarget(this.treeUri);

  final String treeUri;

  @override
  String encode() => '${ExportTarget._safPrefix}$treeUri';

  @override
  Future<String> displayLabel() async {
    try {
      final label = await ExportChannel.treeDisplayPath(treeUri);
      if (label != null && label.isNotEmpty) return label;
    } catch (_) {}
    return treeUri;
  }

  @override
  Future<bool> isUsable() async {
    if (!Platform.isAndroid) return false;
    try {
      return await ExportChannel.isTreeGranted(treeUri);
    } catch (_) {
      return false;
    }
  }

  @override
  Future<ExportSink> openSink({
    required String fileName,
    required String mimeType,
  }) async {
    final uri = await ExportChannel.createInTree(
      treeUri: treeUri,
      name: fileName,
      mime: mimeType,
    );
    if (uri == null) {
      throw const ExportChannelException('无法在所选目录创建文件');
    }
    return ContentUriSink(uri, isPending: false);
  }
}

/// 一次导出的输出目标。
abstract interface class ExportSink {
  /// 传给 ffmpeg 的输出参数。对 `content://` 而言是 `saf:` 形式。
  Future<String> ffmpegOutput();

  /// 直接写入字节，用于 ASS 之类的小文件。
  Future<void> writeBytes(Uint8List bytes);

  /// 从本地文件搬运，ffmpeg 无法直写目标时的兜底。
  Future<void> importFrom(File file);

  /// 收尾，让文件对外可见。
  Future<void> commit();

  /// 放弃并清理已产生的残留。
  Future<void> abort();

  /// 展示给用户的位置。
  Future<String> displayLabel();
}

/// 写入普通文件。
final class FsSink implements ExportSink {
  FsSink(this.file);

  final File file;

  @override
  Future<String> ffmpegOutput() async => file.path;

  @override
  Future<void> writeBytes(Uint8List bytes) => file.writeAsBytes(bytes);

  @override
  Future<void> importFrom(File source) async {
    await source.copy(file.path);
  }

  @override
  Future<void> commit() async {}

  @override
  Future<void> abort() async {
    try {
      if (file.existsSync()) {
        await file.delete();
      }
    } catch (_) {}
  }

  @override
  Future<String> displayLabel() async => file.path;
}

/// 写入 Android `content://` uri。
final class ContentUriSink implements ExportSink {
  ContentUriSink(this.uri, {required this.isPending});

  final String uri;

  /// MediaStore 插入的条目需要清除 pending 标记；SAF 文档不需要。
  final bool isPending;

  @override
  Future<String> ffmpegOutput() async {
    final saf = await FFmpegSafBridge.parameterForWrite(uri);
    if (saf == null || saf.isEmpty) {
      throw const ExportChannelException('无法获取可写入的文件句柄');
    }
    return saf;
  }

  @override
  Future<void> writeBytes(Uint8List bytes) =>
      ExportChannel.writeBytes(uri, bytes);

  @override
  Future<void> importFrom(File file) async {
    await ExportChannel.copyFromFile(uri, file.path);
  }

  @override
  Future<void> commit() async {
    if (isPending) {
      await ExportChannel.finalizePending(uri);
    }
  }

  @override
  Future<void> abort() async {
    try {
      await ExportChannel.deleteDocument(uri);
    } catch (_) {}
  }

  @override
  Future<String> displayLabel() async {
    try {
      final label = await ExportChannel.documentDisplayPath(uri);
      if (label != null && label.isNotEmpty) return label;
    } catch (_) {}
    return uri;
  }
}

/// 启动时解析导出位置。
///
/// 用户设置不可用（SAF 授权失效、目录被删）时静默回退到平台默认值，
/// 但不清除设置项，等用户下次进设置页时自行处理。
Future<void> initExportTarget(String? pref) async {
  final saved = ExportTarget.decode(pref);
  if (saved != null && await saved.isUsable()) {
    await setExportTarget(saved);
    return;
  }
  await setExportTarget(await ExportTarget.platformDefault());
}

/// 隔离 ffmpeg-kit 的 SAF 桥接，让本文件不直接依赖 ffmpeg 包。
///
/// 由 `cache_export_service` 在启动时通过 [register] 注入真实实现。
abstract final class FFmpegSafBridge {
  static Future<String?> Function(String uri)? _resolver;

  // ignore: use_setters_to_change_properties
  static void register(Future<String?> Function(String uri) resolver) {
    _resolver = resolver;
  }

  static Future<String?> parameterForWrite(String uri) {
    final resolver = _resolver;
    if (resolver == null) {
      throw const ExportChannelException('导出组件尚未初始化');
    }
    return resolver(uri);
  }
}
