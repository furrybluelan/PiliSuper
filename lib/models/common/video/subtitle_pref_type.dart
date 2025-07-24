enum SubtitlePrefType { off, on, withoutAi, auto }

extension SubtitlePrefTypeExt on SubtitlePrefType {
  String get description => const [
    '默认不显示字幕',
    '优先选择非自动生成(ai)字幕',
    '跳过自动生成(ai)字幕，选择第一个可用字幕',
    '静音时等同第二项，非静音时等同第三项',
  ][index];

  static const List<String> _codeList = ['off', 'on', 'withoutAi', 'auto'];
  String get code => _codeList[index];

  static SubtitlePrefType? fromCode(String code) {
    final index = _codeList.indexOf(code);
    if (index != -1) {
      return SubtitlePrefType.values[index];
    }
    return null;
  }
}
