import 'package:PiliPlus/models/common/enum_with_label.dart';

/// 缓存导出的内容类型。
enum ExportMode implements EnumWithLabel {
  /// 音频轨，转封装为与编码匹配的容器。
  audio('音频'),

  /// 视频轨，转封装为 mp4。
  video('视频'),

  /// 弹幕转 ASS 字幕文件。
  danmaku('弹幕(ASS)'),

  /// 封面图片。
  cover('封面'),

  /// 音视频合并为单个文件，不含弹幕。
  ///
  /// 通常是 mp4；音轨为 FLAC / E-AC-3 时退回 mkv。
  videoAudio('视频+音频'),

  /// 音视频与弹幕合并为单个 mkv。
  muxed('整体导出(MKV)');

  const ExportMode(this.label);

  @override
  final String label;

  /// 是否产出完整的音视频文件。
  ///
  /// 两个完整输出彼此互斥，但可以与弹幕、单轨道导出共存。
  bool get isCombined =>
      this == ExportMode.muxed || this == ExportMode.videoAudio;
}

/// 单项导出的结果。
class ExportItemResult {
  const ExportItemResult.success(this.mode, this.location)
    : error = null,
      cancelled = false;

  const ExportItemResult.failure(this.mode, this.error)
    : location = null,
      cancelled = false;

  const ExportItemResult.cancelled(this.mode)
    : location = null,
      error = null,
      cancelled = true;

  final ExportMode mode;

  /// 成功时的落盘位置，用于展示。
  final String? location;

  final String? error;

  final bool cancelled;

  bool get isSuccess => error == null && !cancelled;
}

/// 导出阶段，用于进度提示。
enum ExportStage {
  idle('准备中'),
  danmaku('转换弹幕'),
  audio('导出音频'),
  video('导出视频'),
  cover('导出封面'),
  merging('合并音视频'),
  muxing('合并封装'),
  finishing('收尾');

  const ExportStage(this.message);

  final String message;
}
