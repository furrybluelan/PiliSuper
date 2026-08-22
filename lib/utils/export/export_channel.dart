import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/services.dart' show MethodChannel, PlatformException;

/// 导出落盘的原生通道。
///
/// 仅 Android 实现：分区存储下无法用 `File` 写入公共 Download 目录，
/// 需要 MediaStore 插入或 SAF 文档创建。其他平台一律直接用 `dart:io`。
abstract final class ExportChannel {
  static const MethodChannel _channel = MethodChannel('com.pili.super/export');

  static bool get isSupported => Platform.isAndroid;

  /// 公共 Download 目录的真实路径，仅 API 24~28 可直写。
  static Future<String?> publicDownloadsDir() =>
      _invoke<String>('publicDownloadsDir');

  /// 在 MediaStore Downloads 下创建待写入条目，返回 `content://` uri。
  ///
  /// 条目以 pending 状态插入，写完必须调用 [finalizePending]。
  static Future<String?> createInDownloads({
    required String name,
    required String mime,
    String? relativePath,
  }) => _invoke<String>('createInDownloads', {
    'name': name,
    'mime': mime,
    'relativePath': ?relativePath,
  });

  /// 在已授权的 SAF tree 下创建文档，返回 `content://` uri。
  static Future<String?> createInTree({
    required String treeUri,
    required String name,
    required String mime,
    String? subDir,
  }) => _invoke<String>('createInTree', {
    'treeUri': treeUri,
    'name': name,
    'mime': mime,
    'subDir': ?subDir,
  });

  /// 补一次持久化授权，避免进程重启后授权丢失。
  static Future<bool> persistTree(String treeUri) async =>
      await _invoke<bool>('persistTree', {'treeUri': treeUri}) ?? false;

  static Future<bool> isTreeGranted(String treeUri) async =>
      await _invoke<bool>('isTreeGranted', {'treeUri': treeUri}) ?? false;

  /// tree uri 的可读展示路径。
  static Future<String?> treeDisplayPath(String treeUri) =>
      _invoke<String>('treeDisplayPath', {'treeUri': treeUri});

  static Future<String?> documentDisplayPath(String uri) =>
      _invoke<String>('documentDisplayPath', {'uri': uri});

  /// 清除 pending 标记，让文件对其他应用可见。
  static Future<void> finalizePending(String uri) =>
      _invoke<void>('finalizePending', {'uri': uri});

  static Future<bool> deleteDocument(String uri) async =>
      await _invoke<bool>('deleteDocument', {'uri': uri}) ?? false;

  /// 清理中断导出遗留的 pending MediaStore 条目，返回删除数量。
  ///
  /// 条目以 pending 状态插入后若进程被杀，对其他应用不可见，
  /// 却持续占用公共存储空间，需要在启动时回收。
  static Future<int?> clearPendingDownloads() =>
      _invoke<int>('clearPendingDownloads');

  static Future<void> writeBytes(String uri, Uint8List bytes) =>
      _invoke<void>('writeBytes', {'uri': uri, 'bytes': bytes});

  /// 从本地文件流式拷贝进目标 uri，返回写入字节数。
  static Future<int?> copyFromFile(String uri, String path) =>
      _invoke<int>('copyFromFile', {'uri': uri, 'path': path});

  /// 启动前台服务并展示进度通知。
  ///
  /// ffmpeg 在应用进程内运行，Android 14+ 的缓存进程冻结会中断长时间转封装，
  /// 因此后台运行必须依赖前台服务。
  static Future<void> startForegroundProgress({
    required String title,
    required String message,
  }) => _invoke<void>('startForegroundProgress', {
    'title': title,
    'message': message,
  });

  /// 更新进度通知，[progress] 为 0~100，负数表示进度未知。
  static Future<void> updateForegroundProgress({
    required String title,
    required String message,
    required int progress,
  }) => _invoke<void>('updateForegroundProgress', {
    'title': title,
    'message': message,
    'progress': progress,
  });

  static Future<void> stopForegroundProgress() =>
      _invoke<void>('stopForegroundProgress');

  /// 注册通知栏「取消」的回调。
  static void setNotificationCancelHandler(VoidCallback? handler) {
    if (!isSupported) return;
    if (handler == null) {
      _channel.setMethodCallHandler(null);
      return;
    }
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onNotificationCancel') {
        handler();
      }
      return null;
    });
  }

  static Future<T?> _invoke<T>(
    String method, [
    Map<String, Object?>? args,
  ]) async {
    if (!isSupported) {
      throw UnsupportedError('ExportChannel is Android-only');
    }
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      // 原始异常字符串会把 stacktrace 一并带到 UI 上。
      throw ExportChannelException.from(e);
    }
  }
}

/// 原生通道调用失败时抛出的异常。
class ExportChannelException implements Exception {
  const ExportChannelException(this.message);

  factory ExportChannelException.from(PlatformException e) =>
      ExportChannelException(e.message ?? e.code);

  final String message;

  @override
  String toString() => message;
}
