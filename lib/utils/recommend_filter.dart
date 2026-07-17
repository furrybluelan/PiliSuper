import 'package:PiliPlus/models/model_video.dart';
import 'package:PiliPlus/utils/ban_word_utils.dart';
import 'package:PiliPlus/utils/storage_pref.dart';

abstract final class RecommendFilter {
  static int minDurationForRcmd = Pref.minDurationForRcmd;
  static int minPlayForRcmd = Pref.minPlayForRcmd;
  static int minLikeRatioForRecommend = Pref.minLikeRatioForRecommend;
  static bool exemptFilterForFollowed = Pref.exemptFilterForFollowed;
  static bool applyFilterToRelatedVideos = Pref.applyFilterToRelatedVideos;

  static RegExp rcmdRegExp = BanWordUtils.buildRegExp(Pref.banWordForRecommend);
  static bool enableFilter = rcmdRegExp.pattern.isNotEmpty;

  static RegExp descRegExp = BanWordUtils.buildRegExp(Pref.banWordForDesc);
  static bool enableDescFilter = descRegExp.pattern.isNotEmpty;

  static RegExp tagRegExp = BanWordUtils.buildRegExp(Pref.banWordForTag);
  static bool enableTagFilter = tagRegExp.pattern.isNotEmpty;

  static RegExp topicRegExp = BanWordUtils.buildRegExp(Pref.banWordForTopic);
  static bool enableTopicFilter = topicRegExp.pattern.isNotEmpty;

  static Map<int, String> recommendBlockedMids = Pref.recommendBlockedMids;

  static bool filterUser(int? mid) {
    return recommendBlockedMids.isNotEmpty &&
        mid != null &&
        recommendBlockedMids.containsKey(mid);
  }

  static bool filter(BaseVideoItemModel videoItem) {
    if (filterUser(videoItem.owner.mid)) {
      return true;
    }
    if (videoItem.isFollowed && exemptFilterForFollowed) {
      return false;
    }
    return filterAll(videoItem);
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

  /// tags / topics 为名称列表；任一项命中即屏蔽
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
