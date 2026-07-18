import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/ban_word_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

/// 过滤器作用范围
enum FilterScope {
  /// 首页推荐（始终应用）
  rcmd,

  /// 详情相关视频
  related,

  /// 热门
  hot,

  /// 分区/排行
  rank,

  /// 搜索（仅标题 + 屏蔽 UP）
  search,
}

abstract final class RecommendFilter {
  static int minDurationForRcmd = Pref.minDurationForRcmd;
  static int minPlayForRcmd = Pref.minPlayForRcmd;
  static int minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  static bool exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  static bool applyFilterToRelatedVideos = Pref.applyFilterToRelatedVideos;
  static bool applyFilterToHotVideos = Pref.applyFilterToHotVideos;
  static bool applyFilterToRankVideos = Pref.applyFilterToRankVideos;
  static bool applyFilterToSearch = Pref.applyFilterToSearch;

  static RegExp rcmdRegExp = BanWordUtils.buildRegExp(Pref.banWordForRecommend);
  static bool enableFilter = rcmdRegExp.pattern.isNotEmpty;

  static RegExp descRegExp = BanWordUtils.buildRegExp(Pref.banWordForDesc);
  static bool enableDescFilter = descRegExp.pattern.isNotEmpty;

  static RegExp tagRegExp = BanWordUtils.buildRegExp(Pref.banWordForTag);
  static bool enableTagFilter = tagRegExp.pattern.isNotEmpty;

  static RegExp topicRegExp = BanWordUtils.buildRegExp(Pref.banWordForTopic);
  static bool enableTopicFilter = topicRegExp.pattern.isNotEmpty;

  static Map<int, String> recommendBlockedMids = Pref.recommendBlockedMids;
  static Set<String> blockedRcmdTypes = Pref.blockedRcmdTypes;

  static bool isScopeEnabled(FilterScope scope) => switch (scope) {
    FilterScope.rcmd => true,
    FilterScope.related => applyFilterToRelatedVideos,
    FilterScope.hot => applyFilterToHotVideos,
    FilterScope.rank => applyFilterToRankVideos,
    FilterScope.search => applyFilterToSearch,
  };

  static bool filterUser(int? mid) {
    return recommendBlockedMids.isNotEmpty &&
        mid != null &&
        mid > 0 &&
        recommendBlockedMids.containsKey(mid);
  }

  /// 推流稿件类型是否应屏蔽（goto / card_goto）
  static bool filterRcmdType(String? goto) {
    if (goto == null || goto.isEmpty || blockedRcmdTypes.isEmpty) {
      return false;
    }
    return blockedRcmdTypes.contains(goto);
  }

  static bool filterLikeRatio(int? like, int? view) {
    if (view != null) {
      return (view > -1 && view < minPlayForRcmd) ||
          (like != null &&
              like > -1 &&
              like * 100 < minLikeRatioForRecommend * view);
    }
    return false;
  }

  static bool filterTitle(String title) {
    return enableFilter && rcmdRegExp.hasMatch(title);
  }

  static bool filterDesc(String? desc) {
    if (!enableDescFilter || desc == null || desc.isEmpty) return false;
    return descRegExp.hasMatch(desc);
  }

  static bool filterTags(Iterable<String>? tags) {
    if (!enableTagFilter || tags == null) return false;
    for (final t in tags) {
      if (t.isNotEmpty && tagRegExp.hasMatch(t)) return true;
    }
    return false;
  }

  static bool filterTopics(Iterable<String>? topics) {
    if (!enableTopicFilter || topics == null) return false;
    for (final t in topics) {
      if (t.isNotEmpty && topicRegExp.hasMatch(t)) return true;
    }
    return false;
  }

  /// 搜索：仅标题 + 本地屏蔽 UP
  static bool filterForSearch({int? mid, required String title}) {
    if (!applyFilterToSearch) return false;
    if (filterUser(mid)) return true;
    return filterTitle(title);
  }

  /// 完整过滤（推荐/热门/排行/相关）
  static bool filter(
    BaseVideoItemModel videoItem, {
    FilterScope scope = FilterScope.rcmd,
  }) {
    if (!isScopeEnabled(scope)) return false;

    if (filterUser(videoItem.owner.mid)) {
      return true;
    }

    // 搜索范围已在 filterForSearch 处理；此处完整规则
    if (scope == FilterScope.search) {
      return filterTitle(videoItem.title);
    }

    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }
    return filterAll(videoItem);
  }

  static bool filterAll(BaseVideoItemModel videoItem) {
    if (filterUser(videoItem.owner.mid)) {
      return true;
    }
    return (videoItem.duration > 0 &&
            videoItem.duration < minDurationForRcmd) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterTitle(videoItem.title) ||
        filterDesc(videoItem.desc);
  }
}
