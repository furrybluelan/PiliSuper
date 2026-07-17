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
    //由于相关视频中没有已关注标签，只能视为非关注视频
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

  static bool filterAll(BaseVideoItemModel videoItem) {
    if (filterUser(videoItem.owner.mid)) {
      return true;
    }
    return (videoItem.duration > 0 &&
            videoItem.duration < minDurationForRcmd) ||
        filterLikeRatio(videoItem.stat.like, videoItem.stat.view) ||
        filterTitle(videoItem.title);
  }
}
