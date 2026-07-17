import 'package:PiliPlus/http/video.dart';
import 'package:PiliPlus/utils/ban_word_utils.dart';
import 'package:PiliPlus/utils/global_data.dart';
import 'package:PiliPlus/utils/recommend_filter.dart';
import 'package:PiliPlus/utils/storage.dart';
import 'package:PiliPlus/utils/storage_key.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 本地屏蔽维度（与官方账号黑名单分离）
enum LocalBlockType {
  up('UP'),
  title('标题关键词'),
  zone('视频分区'),
  tag('视频TAG'),
  topic('视频话题'),
  desc('简介屏蔽词');

  final String label;
  const LocalBlockType(this.label);

  bool get isUp => this == LocalBlockType.up;

  String get storageKey => switch (this) {
    LocalBlockType.title => SettingBoxKey.banWordForRecommend,
    LocalBlockType.zone => SettingBoxKey.banWordForZone,
    LocalBlockType.tag => SettingBoxKey.banWordForTag,
    LocalBlockType.topic => SettingBoxKey.banWordForTopic,
    LocalBlockType.desc => SettingBoxKey.banWordForDesc,
    LocalBlockType.up => '', // 使用 local cache map
  };

  List<String> loadRules() {
    if (isUp) {
      return Pref.recommendBlockedMids.entries
          .map((e) => '${e.value} (${e.key})')
          .toList();
    }
    final stored = GStorage.setting.get(storageKey, defaultValue: '') as String;
    return BanWordUtils.parseItems(stored);
  }

  void saveRules(List<String> items) {
    if (isUp) {
      final map = <int, String>{};
      for (final item in items) {
        // 从右侧解析 mid，避免名称中含括号时被截断
        final match = RegExp(r'^(.*)\s*\((\d+)\)$').firstMatch(item.trim());
        if (match != null) {
          final name = match.group(1)?.trim() ?? '';
          final uid = int.tryParse(match.group(2) ?? '');
          if (uid != null && uid > 0) {
            map[uid] = name.isEmpty ? 'UID:$uid' : name;
          }
        } else {
          final uid = int.tryParse(item.trim());
          if (uid != null && uid > 0) {
            map[uid] = 'UID:$uid';
          }
        }
      }
      Pref.recommendBlockedMids = map;
      GlobalData().recommendBlockedMids = map;
      RecommendFilter.recommendBlockedMids = map;
      return;
    }
    final stored = BanWordUtils.joinItems(items);
    GStorage.setting.put(storageKey, stored);
    applyRegExp(BanWordUtils.buildRegExp(stored));
  }

  void applyRegExp(RegExp re) {
    switch (this) {
      case LocalBlockType.title:
        RecommendFilter.rcmdRegExp = re;
        RecommendFilter.enableFilter = re.pattern.isNotEmpty;
        break;
      case LocalBlockType.zone:
        VideoHttp.zoneRegExp = re;
        VideoHttp.enableFilter = re.pattern.isNotEmpty;
        break;
      case LocalBlockType.tag:
        RecommendFilter.tagRegExp = re;
        RecommendFilter.enableTagFilter = re.pattern.isNotEmpty;
        break;
      case LocalBlockType.topic:
        RecommendFilter.topicRegExp = re;
        RecommendFilter.enableTopicFilter = re.pattern.isNotEmpty;
        break;
      case LocalBlockType.desc:
        RecommendFilter.descRegExp = re;
        RecommendFilter.enableDescFilter = re.pattern.isNotEmpty;
        break;
      case LocalBlockType.up:
        break;
    }
  }

  /// 将单条规则写入存储并热更新
  void appendRule(String rule) {
    if (isUp) return;
    final stored = GStorage.setting.get(storageKey, defaultValue: '') as String;
    final next = BanWordUtils.appendRule(stored, rule);
    GStorage.setting.put(storageKey, next);
    applyRegExp(BanWordUtils.buildRegExp(next));
  }

  String get addHint => switch (this) {
    LocalBlockType.up => '输入用户 UID',
    LocalBlockType.title => '标题关键词或 /正则/flags',
    LocalBlockType.zone => '分区名或 /正则/flags',
    LocalBlockType.tag => 'TAG 或 /正则/flags',
    LocalBlockType.topic => '话题名或 /正则/flags',
    LocalBlockType.desc => '简介关键词或 /正则/flags',
  };
}
