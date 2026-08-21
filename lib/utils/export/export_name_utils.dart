import 'dart:convert' show utf8;

/// 生成落盘文件名。
abstract final class ExportNameUtils {
  /// 各平台与 MediaStore / SAF 都拒绝的字符。
  static final RegExp _illegal = RegExp(r'[\\/:*?"<>|\x00-\x1F\x7F]');

  /// 文件名主干的最大字节数。
  ///
  /// 多数文件系统限制为 255 字节，中文按 UTF-8 占 3 字节，
  /// 留出扩展名与去重后缀的余量。
  static const int _maxStemBytes = 160;

  /// 把标题清洗成安全的文件名主干。
  static String sanitizeStem(String raw) {
    // 先归一化空白，否则 tab/换行会先被当作控制字符替换成下划线。
    var stem = raw
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(_illegal, '_')
        .trim();
    // Windows 不允许以点或空格结尾。
    stem = stem.replaceAll(RegExp(r'[. ]+$'), '');
    if (stem.isEmpty) stem = 'export';
    return _truncateBytes(stem, _maxStemBytes);
  }

  /// 按 UTF-8 字节数截断，不切断字符。
  static String _truncateBytes(String value, int maxBytes) {
    if (utf8.encode(value).length <= maxBytes) return value;
    final buffer = StringBuffer();
    var used = 0;
    for (final rune in value.runes) {
      final char = String.fromCharCode(rune);
      final size = utf8.encode(char).length;
      if (used + size > maxBytes) break;
      buffer.write(char);
      used += size;
    }
    final result = buffer.toString().trim();
    return result.isEmpty ? 'export' : result;
  }

  static String join(String stem, String extension) =>
      '$stem${extension.startsWith('.') ? extension : '.$extension'}';
}
