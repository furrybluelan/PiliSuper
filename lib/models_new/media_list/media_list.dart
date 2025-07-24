import 'package:PiliPlus/models/model_owner.dart';
import 'package:PiliPlus/models_new/fav/fav_detail/cnt_info.dart';
import 'package:PiliPlus/models_new/media_list/badge.dart';
import 'package:PiliPlus/models_new/media_list/coin.dart';
import 'package:PiliPlus/models_new/media_list/ogv_info.dart';
import 'package:PiliPlus/models_new/media_list/page.dart';
import 'package:PiliPlus/models_new/media_list/rights.dart';
import 'package:PiliPlus/utils/extension.dart';

class MediaListItemModel {
  int? get id => aid;
  int? aid;
  int? offset;
  int? index;
  String? intro;
  int? attr;
  int? tid;
  int? copyRight;
  CntInfo? cntInfo;
  String? cover;
  int? duration;
  int? pubtime;
  int? likeState;
  int? favState;
  int? page;
  List<Page>? pages;
  String? title;
  int? type;
  Owner? upper;
  String? link;
  String? bvid;
  String? shortLink;
  Rights? rights;
  dynamic elecInfo;
  Coin? coin;
  OgvInfo? ogvInfo;
  double? progressPercent;
  Badge? badge;
  bool? forbidFav;
  int? moreType;
  int? businessOid;
  int? cid;

  MediaListItemModel({
    this.aid,
    this.offset,
    this.index,
    this.intro,
    this.attr,
    this.tid,
    this.copyRight,
    this.cntInfo,
    this.cover,
    this.duration,
    this.pubtime,
    this.likeState,
    this.favState,
    this.page,
    this.pages,
    this.title,
    this.type,
    this.upper,
    this.link,
    this.bvid,
    this.shortLink,
    this.rights,
    this.elecInfo,
    this.coin,
    this.ogvInfo,
    this.progressPercent,
    this.badge,
    this.forbidFav,
    this.moreType,
    this.businessOid,
    this.cid,
  });

  MediaListItemModel.fromJson(Map<String, dynamic> json) {
    aid = json['id'] as int?;
    offset = json['offset'] as int?;
    index = json['index'] as int?;
    intro = json['intro'] as String?;
    attr = json['attr'] as int?;
    tid = json['tid'] as int?;
    copyRight = json['copy_right'] as int?;
    cntInfo = json['cnt_info'] == null
        ? null
        : CntInfo.fromJson(json['cnt_info']);
    cover = json['cover'] as String?;
    duration = json['duration'] as int?;
    pubtime = json['pubtime'] as int?;
    likeState = json['like_state'] as int?;
    favState = json['fav_state'] as int?;
    page = json['page'] as int?;
    pages = (json['pages'] as List?)?.map((e) => Page.fromJson(e)).toList();
    title = json['title'] as String?;
    type = json['type'] as int?;
    upper = json['upper'] == null ? null : Owner.fromJson(json['upper']);
    link = json['link'] as String?;
    bvid = json['bv_id'] as String?;
    shortLink = json['short_link'] as String?;
    rights = json['rights'] == null ? null : Rights.fromJson(json['rights']);
    elecInfo = json['elec_info'] as dynamic;
    coin = json['coin'] == null ? null : Coin.fromJson(json['coin']);
    ogvInfo = json['ogv_info'] == null
        ? null
        : OgvInfo.fromJson(json['ogv_info']);
    progressPercent = (json['progress_percent'] as num?)?.toDouble();
    badge = json['badge'] == null ? null : Badge.fromJson(json['badge']);
    forbidFav = json['forbid_fav'] as bool?;
    moreType = json['more_type'] as int?;
    businessOid = json['business_oid'] as int?;
    cid = pages.getOrNull((page ?? 1) - 1)?.id;
  }
}
