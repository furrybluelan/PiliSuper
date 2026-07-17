/// 本地屏蔽关键词解析：支持普通文字与 JavaScript 风格正则。
///
/// 存储格式：每行一条规则。
/// 规则语法：
/// - 普通文字：按字面匹配（自动转义）
/// - JS 正则：`/pattern/flags`，例如 `/foo.*bar/i`
abstract final class BanWordUtils {
  static final _jsRegex = RegExp(r'^/(.*)/([gimsuy]*)$', dotAll: true);

  /// 将存储字符串解析为规则列表（仅换行分隔）
  static List<String> parseItems(String stored) {
    if (stored.isEmpty) return [];
    return stored
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  static String joinItems(List<String> items) => items.join('\n');

  /// 单条规则 → 正则片段（不带首尾 /）
  static String ruleToPattern(String rule) {
    final trimmed = rule.trim();
    if (trimmed.isEmpty) return '';

    final m = _jsRegex.firstMatch(trimmed);
    if (m != null) {
      return m.group(1) ?? '';
    }
    return RegExp.escape(trimmed);
  }

  /// 存储字符串 → 用于 [RegExp] 的 pattern（多规则用 | 连接）
  /// 单条非法正则会被跳过
  static String parseBanWordToRegex(String stored) {
    final items = parseItems(stored);
    if (items.isEmpty) return '';

    final patterns = <String>[];
    for (final item in items) {
      final p = ruleToPattern(item);
      if (p.isEmpty) continue;
      final candidate = (p.contains('|') && !p.startsWith('(')) ? '($p)' : p;
      try {
        RegExp(candidate, caseSensitive: false);
        patterns.add(candidate);
      } catch (_) {}
    }
    return patterns.join('|');
  }

  static RegExp buildRegExp(String stored) {
    final pattern = parseBanWordToRegex(stored);
    if (pattern.isEmpty) return RegExp('');
    try {
      return RegExp(pattern, caseSensitive: false);
    } catch (_) {
      return RegExp('');
    }
  }

  /// 追加一条规则（去重），返回新存储串
  static String appendRule(String stored, String rule) {
    final keyword = rule.trim();
    if (keyword.isEmpty) return stored;
    final items = parseItems(stored);
    if (items.contains(keyword)) return stored;
    items.add(keyword);
    return joinItems(items);
  }
}
