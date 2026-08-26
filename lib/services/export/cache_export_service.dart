import 'dart:async';
import 'dart:convert' show jsonDecode, utf8;
import 'dart:io';
import 'dart:isolate';

import 'package:PiliPlus/grpc/bilibili/community/service/dm/v1.pb.dart'
    show DmSegMobileReply;
import 'package:PiliPlus/models/common/export_mode.dart';
import 'package:PiliPlus/models/common/video/audio_quality.dart';
import 'package:PiliPlus/models_new/download/bili_download_entry_info.dart';
import 'package:PiliPlus/models_new/download/bili_download_media_file_info.dart';
import 'package:PiliPlus/utils/ass_utils.dart';
import 'package:PiliPlus/utils/device_utils.dart';
import 'package:PiliPlus/utils/export/export_channel.dart';
import 'package:PiliPlus/utils/export/export_name_utils.dart';
import 'package:PiliPlus/utils/export/export_target.dart';
import 'package:PiliPlus/utils/image_utils.dart';
import 'package:PiliPlus/utils/path_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:ffmpeg_kit_flutter_new_min/return_code.dart';
import 'package:ffmpeg_kit_flutter_new_min/statistics.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

/// 缓存导出。
///
/// 缓存目录里音视频是分离的 DASH 流 (`video.m4s` / `audio.m4s`)，
/// 或 DURL 回退时的单个 `0.mp4`。导出全部走 ffmpeg 转封装 (`-c copy`)，
/// 不重新编码。弹幕从 `danmaku.pb` 解出后转 ASS。
class CacheExportService extends GetxService {
  /// 当前进度，0~1；无法估算时为 -1。
  final progress = (-1.0).obs;
  final stage = ExportStage.idle.obs;
  final currentLabel = ''.obs;
  final isExporting = false.obs;

  int? _sessionId;
  bool _cancelled = false;

  /// 通知栏进度上次上报的百分比与文案，避免高频跨通道调用。
  int _lastNotifiedPercent = -2;
  String _lastNotifiedMessage = '';

  /// 清理上次进程中断遗留的导出残留。
  ///
  /// 中转文件位于系统临时目录，进程被杀时 `finally` 不会执行；
  /// MediaStore 的 pending 条目同样会滞留公共存储，都需启动时清扫。
  static Future<void> purgeStaleExports() async {
    try {
      final dir = Directory(tmpDirPath);
      if (dir.existsSync()) {
        for (final entity in dir.listSync()) {
          if (entity is File &&
              path.basename(entity.path).startsWith('export_')) {
            try {
              entity.deleteSync();
            } catch (_) {}
          }
        }
      }
    } catch (_) {}
    if (ExportChannel.isSupported && DeviceUtils.sdkInt >= 29) {
      try {
        await ExportChannel.clearPendingDownloads();
      } catch (_) {}
    }
  }

  @override
  void onInit() {
    super.onInit();
    // ContentUriSink 需要 ffmpeg 的 SAF 参数，但 export_target 不直接依赖 ffmpeg。
    FFmpegSafBridge.register(FFmpegKitConfig.getSafParameterForWrite);
    if (ExportChannel.isSupported) {
      ExportChannel.setNotificationCancelHandler(cancel);
    }
  }

  @override
  void onClose() {
    if (ExportChannel.isSupported) {
      ExportChannel.setNotificationCancelHandler(null);
    }
    super.onClose();
  }

  /// 判断某个模式对该缓存条目是否可用。
  static bool isModeAvailable(BiliDownloadEntryInfo entry, ExportMode mode) {
    if (!entry.isCompleted) return false;
    // DURL 单文件里音频是内嵌的，可以抽取；DASH 则要求确有 audio.m4s。
    final hasAudio = entry.mediaType == 1 || entry.hasDashAudio;
    return switch (mode) {
      ExportMode.audio => hasAudio,
      ExportMode.video => true,
      ExportMode.danmaku => File(
        path.join(entry.entryDirPath, PathUtils.danmakuName),
      ).existsSync(),
      ExportMode.cover => File(
        path.join(entry.entryDirPath, PathUtils.coverName),
      ).existsSync(),
      // 没有音轨时与「视频」完全等价，不重复提供。
      ExportMode.videoAudio => hasAudio,
      ExportMode.muxed => true,
    };
  }

  /// 执行导出。返回每一项的结果，互不影响。
  Future<List<ExportItemResult>> export({
    required BiliDownloadEntryInfo entry,
    required Set<ExportMode> modes,
  }) async {
    if (isExporting.value) {
      return [
        for (final mode in modes) ExportItemResult.failure(mode, '已有导出任务在进行'),
      ];
    }

    // Android 9 及以下写公共 Download 目录需要存储权限；
    // 29+ 走 MediaStore/SAF 无需申请，其他平台也不需要。
    if (Platform.isAndroid &&
        DeviceUtils.sdkInt < 29 &&
        exportTarget is FsTarget &&
        !await ImageUtils.requestPer()) {
      return [
        for (final mode in modes) ExportItemResult.failure(mode, '未获得存储权限'),
      ];
    }

    // 真实写探针验证（创建 + 删除），授权被收紧或目录只读时直接整体报错，
    // 而不是每个导出项都在写入阶段才失败。
    if (!await exportTarget.probeWritable()) {
      return [
        for (final mode in modes)
          ExportItemResult.failure(mode, '导出位置不可用，请在设置中重新选择'),
      ];
    }

    _cancelled = false;
    isExporting.value = true;
    _lastNotifiedPercent = -2;
    _lastNotifiedMessage = '';
    await _startNotification();
    final results = <ExportItemResult>[];
    _ExportContext? context;
    try {
      context = await _ExportContext.of(entry);
      // ExportMode 的声明顺序即执行顺序：单轨道在前，合并输出在后。
      final ordered = ExportMode.values.where(modes.contains);
      for (final mode in ordered) {
        if (_cancelled) {
          results.add(ExportItemResult.cancelled(mode));
          continue;
        }
        results.add(await _runOne(context, mode));
      }
    } catch (e) {
      // 上下文构建失败时无法归因到具体项，逐项报同一错误。
      final message = e.toString();
      for (final mode in modes) {
        results.add(ExportItemResult.failure(mode, message));
      }
    } finally {
      await context?.dispose();
      await _stopNotification();
      isExporting.value = false;
      stage.value = ExportStage.idle;
      progress.value = -1;
      currentLabel.value = '';
      _sessionId = null;
    }
    return results;
  }

  Future<void> cancel() async {
    _cancelled = true;
    final id = _sessionId;
    if (id != null) {
      await FFmpegKit.cancel(id);
    }
  }

  Future<void> _startNotification() async {
    if (!ExportChannel.isSupported) return;
    try {
      await ExportChannel.startForegroundProgress(
        title: '正在导出缓存',
        message: ExportStage.idle.message,
      );
    } catch (_) {}
  }

  Future<void> _stopNotification() async {
    if (!ExportChannel.isSupported) return;
    try {
      await ExportChannel.stopForegroundProgress();
    } catch (_) {}
  }

  /// 同步进度到通知栏，百分比与文案均无变化时跳过。
  void _syncNotification() {
    if (!ExportChannel.isSupported) return;
    final value = progress.value;
    final percent = value < 0 ? -1 : (value * 100).round();
    final label = currentLabel.value;
    final message = label.isEmpty
        ? stage.value.message
        : '${stage.value.message} · $label';
    // 百分比不变也要对比文案：连续的不确定进度阶段（均为 -1）
    // 若只看百分比，通知会一直停留在上一次的标签上。
    if (percent == _lastNotifiedPercent && message == _lastNotifiedMessage) {
      return;
    }
    _lastNotifiedPercent = percent;
    _lastNotifiedMessage = message;
    ExportChannel.updateForegroundProgress(
      title: '正在导出缓存',
      message: message,
      progress: percent,
    ).catchError((_) {});
  }

  Future<ExportItemResult> _runOne(
    _ExportContext context,
    ExportMode mode,
  ) async {
    currentLabel.value = mode.label;
    _syncNotification();
    try {
      return switch (mode) {
        ExportMode.danmaku => await _exportDanmaku(context),
        ExportMode.cover => await _exportCover(context),
        ExportMode.audio => await _exportAudio(context),
        ExportMode.video => await _exportVideo(context),
        ExportMode.videoAudio => await _exportCombined(
          context,
          mode: ExportMode.videoAudio,
          stageValue: ExportStage.merging,
          withDanmaku: false,
        ),
        ExportMode.muxed => await _exportCombined(
          context,
          mode: ExportMode.muxed,
          stageValue: ExportStage.muxing,
          withDanmaku: true,
        ),
      };
    } catch (e) {
      return ExportItemResult.failure(mode, e.toString());
    }
  }

  Future<ExportItemResult> _exportCover(_ExportContext context) async {
    stage.value = ExportStage.cover;
    progress.value = -1;
    final cover = context.coverFile;
    if (cover == null) {
      return const ExportItemResult.failure(ExportMode.cover, '没有缓存封面');
    }
    final sink = await exportTarget.openSink(
      fileName: ExportNameUtils.join(context.stem, '.jpg'),
      mimeType: 'image/jpeg',
    );
    try {
      await sink.importFrom(cover);
      await sink.commit();
      return ExportItemResult.success(
        ExportMode.cover,
        await sink.displayLabel(),
      );
    } catch (e) {
      await sink.abort();
      return ExportItemResult.failure(ExportMode.cover, e.toString());
    }
  }

  Future<ExportItemResult> _exportDanmaku(_ExportContext context) async {
    stage.value = ExportStage.danmaku;
    progress.value = -1;
    final ass = await context.buildAss();
    if (ass == null) {
      return const ExportItemResult.failure(ExportMode.danmaku, '没有可导出的弹幕');
    }
    final sink = await exportTarget.openSink(
      fileName: ExportNameUtils.join(context.stem, '.ass'),
      mimeType: 'text/plain',
    );
    try {
      await sink.writeBytes(utf8.encode(ass));
      await sink.commit();
      return ExportItemResult.success(
        ExportMode.danmaku,
        await sink.displayLabel(),
      );
    } catch (e) {
      await sink.abort();
      return ExportItemResult.failure(ExportMode.danmaku, e.toString());
    }
  }

  Future<ExportItemResult> _exportAudio(_ExportContext context) {
    stage.value = ExportStage.audio;
    // DURL 的音频内嵌在 0.mp4 里，DASH 则是独立的 audio.m4s。
    final source = context.mediaType == 1
        ? context.videoPath
        : context.audioPath;
    if (source == null) {
      return Future.value(
        const ExportItemResult.failure(ExportMode.audio, '缺少音频文件'),
      );
    }
    final (ext, format, mime) = context.audioContainer;
    final args = <String>[
      '-y',
      '-i',
      source,
      '-vn',
      '-map',
      '0:a:0',
      '-c',
      'copy',
    ];
    return _runFfmpeg(
      mode: ExportMode.audio,
      context: context,
      args: args,
      extension: ext,
      forceFormat: format,
      mimeType: mime,
    );
  }

  Future<ExportItemResult> _exportVideo(_ExportContext context) {
    stage.value = ExportStage.video;
    final args = <String>[
      '-y',
      '-i',
      context.videoPath,
      '-an',
      '-map',
      '0:v:0',
      '-c',
      'copy',
    ];
    return _runFfmpeg(
      mode: ExportMode.video,
      context: context,
      args: args,
      extension: '.mp4',
      // fMP4 片段需要显式指定容器，因为输出可能是无扩展名的 saf: 句柄。
      forceFormat: 'mp4',
      mimeType: 'video/mp4',
    );
  }

  /// 音视频合并输出。
  ///
  /// [withDanmaku] 为真时把弹幕 ASS 作为软字幕轨嵌入。mp4 只能容纳 mov_text，
  /// 转换会破坏弹幕排版，所以只有 mkv 会带弹幕。
  ///
  /// 另外，音轨为 FLAC / E-AC-3 时 mp4 无法原生承载，此时「视频+音频」
  /// 也会退回 mkv，避免产出兼容性极差的实验性封装。
  ///
  /// 缓存的 cover.jpg 会作为封面写入：mkv 用 Matroska 的附件封面约定，
  /// mp4 用 `attached_pic` 视频轨。
  Future<ExportItemResult> _exportCombined(
    _ExportContext context, {
    required ExportMode mode,
    required ExportStage stageValue,
    required bool withDanmaku,
  }) async {
    stage.value = stageValue;
    final hasSidecarAudio = context.mediaType != 1 && context.audioPath != null;
    // DASH 缓存声称有音轨但 audio.m4s 丢失时，「视频+音频」会退化成纯视频，
    // 与用户预期不符，直接报错让其改用「视频」。
    if (mode == ExportMode.videoAudio &&
        context.mediaType != 1 &&
        !hasSidecarAudio) {
      return ExportItemResult.failure(mode, '缺少音频文件');
    }
    final useMatroska = withDanmaku || context.needsMatroskaAudio;
    final assPath = withDanmaku ? await context.writeTempAss() : null;
    final cover = context.coverFile;

    final args = <String>['-y'];
    // 输入序号必须与 -map 的引用严格对应，逐个累加而非写死。
    var nextInput = 0;
    final videoInput = nextInput++;
    args.addAll(['-i', context.videoPath]);
    int? audioInput;
    if (hasSidecarAudio) {
      audioInput = nextInput++;
      args.addAll(['-i', context.audioPath!]);
    }
    int? assInput;
    if (assPath != null) {
      assInput = nextInput++;
      args.addAll(['-i', assPath]);
    }
    // mkv 的封面走附件，不占输入；mp4 需要真实的图片输入。
    int? coverInput;
    if (cover != null && !useMatroska) {
      coverInput = nextInput++;
      args.addAll(['-i', cover.path]);
    }

    args.addAll(['-map', '$videoInput:v:0']);
    if (context.mediaType == 1) {
      // DURL 单文件里音频与视频同源，可能没有音轨，用 `?` 容错。
      args.addAll(['-map', '$videoInput:a:0?']);
    } else if (audioInput != null) {
      args.addAll(['-map', '$audioInput:a:0']);
    }
    if (assInput != null) {
      args.addAll([
        '-map',
        '$assInput:s:0',
        '-metadata:s:s:0',
        'language=chi',
        '-metadata:s:s:0',
        'title=弹幕',
        '-disposition:s:0',
        'default',
      ]);
    }
    if (coverInput != null) {
      args.addAll([
        '-map',
        '$coverInput:v:0',
        '-disposition:v:1',
        'attached_pic',
      ]);
    } else if (cover != null) {
      args.addAll([
        '-attach',
        cover.path,
        '-metadata:s:t:0',
        'mimetype=image/jpeg',
        '-metadata:s:t:0',
        'filename=${PathUtils.coverName}',
      ]);
    }
    args.addAll([
      '-c',
      'copy',
      '-metadata',
      'title=${context.entry.showTitle}',
    ]);

    return _runFfmpeg(
      mode: mode,
      context: context,
      args: args,
      extension: useMatroska ? '.mkv' : '.mp4',
      forceFormat: useMatroska ? 'matroska' : 'mp4',
      mimeType: useMatroska ? 'video/x-matroska' : 'video/mp4',
    );
  }

  Future<ExportItemResult> _runFfmpeg({
    required ExportMode mode,
    required _ExportContext context,
    required List<String> args,
    required String extension,
    required String mimeType,
    String? forceFormat,
  }) async {
    final sink = await exportTarget.openSink(
      fileName: ExportNameUtils.join(context.stem, extension),
      mimeType: mimeType,
    );
    File? staging;

    List<String> commandFor(String output) => [
      ...args,
      if (forceFormat != null) ...['-f', forceFormat],
      output,
    ];

    try {
      String? direct;
      try {
        direct = await sink.ffmpegOutput();
      } catch (_) {
        // 拿不到可写句柄，直接走中转文件。
        direct = null;
      }

      ReturnCode? code;
      if (direct != null) {
        code = await _execute(commandFor(direct), context.totalTimeMilli);
        if (ReturnCode.isCancel(code)) {
          await sink.abort();
          return ExportItemResult.cancelled(mode);
        }
      }

      // 直写失败通常是目标句柄不可 seek（mkv/mp4 收尾要回写索引），
      // 用中转文件重试一次再搬运过去。
      if (direct == null || !ReturnCode.isSuccess(code)) {
        staging = context.stagingFile(extension);
        code = await _execute(commandFor(staging.path), context.totalTimeMilli);
        if (ReturnCode.isCancel(code)) {
          await sink.abort();
          return ExportItemResult.cancelled(mode);
        }
        if (!ReturnCode.isSuccess(code)) {
          await sink.abort();
          return ExportItemResult.failure(
            mode,
            'ffmpeg 退出码 ${code?.getValue()}',
          );
        }
      }

      stage.value = ExportStage.finishing;
      _syncNotification();
      if (staging != null) {
        await sink.importFrom(staging);
      }
      await sink.commit();
      return ExportItemResult.success(mode, await sink.displayLabel());
    } catch (e) {
      await sink.abort();
      return ExportItemResult.failure(mode, e.toString());
    } finally {
      if (staging != null && staging.existsSync()) {
        try {
          await staging.delete();
        } catch (_) {}
      }
    }
  }

  Future<ReturnCode?> _execute(List<String> args, int totalTimeMilli) async {
    final completer = Completer<ReturnCode?>();
    progress.value = totalTimeMilli > 0 ? 0 : -1;
    final session = await FFmpegKit.executeWithArgumentsAsync(
      args,
      (session) async {
        if (!completer.isCompleted) {
          completer.complete(await session.getReturnCode());
        }
      },
      null,
      (Statistics statistics) {
        if (totalTimeMilli <= 0) return;
        final value = statistics.getTime() / totalTimeMilli;
        progress.value = value.clamp(0.0, 1.0);
        _syncNotification();
      },
    );
    _sessionId = session.getSessionId();
    if (_cancelled) {
      await FFmpegKit.cancel(_sessionId);
    }
    return completer.future;
  }
}

/// 一次导出所需的路径与元数据。
class _ExportContext {
  _ExportContext({
    required this.entry,
    required this.stem,
    required this.videoPath,
    required this.audioPath,
    required this.mediaType,
    required this.totalTimeMilli,
    required this.audioQualityId,
    required this.width,
    required this.height,
  });

  static Future<_ExportContext> of(BiliDownloadEntryInfo entry) async {
    final typeTag = entry.typeTag;
    if (typeTag == null || typeTag.isEmpty) {
      throw const FormatException('缓存信息不完整');
    }
    final mediaDir = path.join(entry.entryDirPath, typeTag);
    final isMp4 = entry.mediaType == 1;
    final videoPath = path.join(
      mediaDir,
      isMp4 ? PathUtils.videoNameType1 : PathUtils.videoNameType2,
    );
    if (!File(videoPath).existsSync()) {
      throw FileSystemException('缓存文件缺失', videoPath);
    }
    final audioFile = File(path.join(mediaDir, PathUtils.audioNameType2));
    final audioPath = !isMp4 && entry.hasDashAudio && audioFile.existsSync()
        ? audioFile.path
        : null;

    // index.json 提供音轨编号与分辨率，用于挑容器和 ASS 的 PlayRes。
    int? audioQualityId;
    var width = entry.pageData?.width ?? 0;
    var height = entry.pageData?.height ?? 0;
    try {
      final indexFile = File(path.join(mediaDir, 'index.json'));
      if (indexFile.existsSync()) {
        final json =
            jsonDecode(await indexFile.readAsString()) as Map<String, dynamic>;
        if (json['video'] != null) {
          final info = Type2.fromJson(json);
          audioQualityId = info.audio?.firstOrNull?.id;
          final video = info.video.firstOrNull;
          if (video != null && video.width > 1 && video.height > 1) {
            width = video.width;
            height = video.height;
          }
        }
      }
    } catch (_) {}

    return _ExportContext(
      entry: entry,
      stem: ExportNameUtils.sanitizeStem(entry.showTitle),
      videoPath: videoPath,
      audioPath: audioPath,
      mediaType: entry.mediaType,
      totalTimeMilli: entry.totalTimeMilli,
      audioQualityId: audioQualityId,
      width: width > 0 ? width : 1920,
      height: height > 0 ? height : 1080,
    );
  }

  final BiliDownloadEntryInfo entry;
  final String stem;
  final String videoPath;
  final String? audioPath;
  final int mediaType;
  final int totalTimeMilli;
  final int? audioQualityId;
  final int width;
  final int height;

  File? _tempAss;

  final int _token = DateTime.now().microsecondsSinceEpoch;

  /// 音轨是否为 mp4 系容器无法原生承载的编码。
  ///
  /// Hi-Res 是 FLAC、杜比全景声是 E-AC-3，两者放进 mp4/m4a 都属于实验性封装，
  /// 播放器兼容性差，统一改用 Matroska。
  bool get needsMatroskaAudio {
    final id = audioQualityId;
    return id == AudioQuality.hiRes.code ||
        id == AudioQuality.dolby_30250.code ||
        id == AudioQuality.dolby_30255.code;
  }

  /// 单独导出音频时的容器，返回 (扩展名, ffmpeg 容器名, MIME)。
  ///
  /// 输出可能是无扩展名的 `saf:` 句柄，因此必须显式指定容器。
  (String, String, String) get audioContainer => needsMatroskaAudio
      ? ('.mka', 'matroska', 'audio/x-matroska')
      : ('.m4a', 'ipod', 'audio/mp4');

  /// 缓存的封面，缺失时为 `null`。
  File? get coverFile {
    final file = File(path.join(entry.entryDirPath, PathUtils.coverName));
    return file.existsSync() ? file : null;
  }

  Future<String?> buildAss() async {
    final file = File(path.join(entry.entryDirPath, PathUtils.danmakuName));
    if (!file.existsSync()) return null;
    final bytes = await file.readAsBytes();
    final title = entry.showTitle;
    // 弹幕可能上万条，解析与排版放到后台 isolate，避免转换期间卡住 UI。
    // DeviceUtils.size / Pref 依赖主 isolate，必须先取值再传入闭包。
    final options = AssOptions(
      playResX: width,
      playResY: height,
      // 导出的是整幅画面，对应播放器的全屏形态：弹幕层高度为屏幕短边，
      // 字号也用全屏那一档，这样导出观感与用户全屏观看时一致。
      referenceHeight: DeviceUtils.size.shortestSide,
      fontName: Pref.exportAssFontName,
      fontScale: Pref.danmakuFontScaleFS,
      lineHeight: Pref.danmakuLineHeight,
      scrollDuration: Pref.danmakuDuration,
      staticDuration: Pref.danmakuStaticDuration,
      strokeWidth: Pref.danmakuStrokeWidth,
      opacity: Pref.danmakuOpacity,
      showArea: Pref.danmakuShowArea,
      blockTypes: Pref.danmakuBlockType,
      weightThreshold: Pref.danmakuWeight,
    );
    return Isolate.run(() {
      final DmSegMobileReply reply;
      try {
        reply = DmSegMobileReply.fromBuffer(bytes);
      } catch (_) {
        return null;
      }
      if (reply.elems.isEmpty) return null;
      return AssUtils.danmaku2Ass(reply.elems, title: title, options: options);
    });
  }

  /// ffmpeg 需要 ASS 作为输入文件，先落到临时目录。
  Future<String?> writeTempAss() async {
    final ass = await buildAss();
    if (ass == null) return null;
    final file = File(path.join(tmpDirPath, '$_tempPrefix.ass'));
    await file.writeAsString(ass);
    _tempAss = file;
    return file.path;
  }

  /// ffmpeg 无法直写目标时的中转文件。
  File stagingFile(String extension) =>
      File(path.join(tmpDirPath, '$_tempPrefix$extension'));

  String get _tempPrefix => 'export_${entry.cid}_$_token';

  Future<void> dispose() async {
    final temp = _tempAss;
    if (temp != null && temp.existsSync()) {
      try {
        await temp.delete();
      } catch (_) {}
    }
    _tempAss = null;
  }
}
