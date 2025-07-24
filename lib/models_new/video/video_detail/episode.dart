import 'package:PiliPlus/models_new/video/video_detail/arc.dart';
import 'package:PiliPlus/models_new/video/video_detail/page.dart';

class EpisodeItem {
  int? seasonId;
  int? sectionId;
  int? id;
  int? aid;
  int? cid;
  String? title;
  int? attribute;
  Arc? arc;
  Part? page;
  String? bvid;
  List<Part>? pages;
  String? badge;

  EpisodeItem({
    this.seasonId,
    this.sectionId,
    this.id,
    this.aid,
    this.cid,
    this.title,
    this.attribute,
    this.arc,
    this.page,
    this.bvid,
    this.pages,
    this.badge,
  });

  factory EpisodeItem.fromJson(Map<String, dynamic> json) => EpisodeItem(
    seasonId: json['season_id'] as int?,
    sectionId: json['section_id'] as int?,
    id: json['id'] as int?,
    aid: json['aid'] as int?,
    cid: json['cid'] as int?,
    title: json['title'] as String?,
    attribute: json['attribute'] as int?,
    arc: json['arc'] == null
        ? null
        : Arc.fromJson(json['arc'] as Map<String, dynamic>),
    page: json['page'] == null
        ? null
        : Part.fromJson(json['page'] as Map<String, dynamic>),
    bvid: json['bvid'] as String?,
    pages: (json['pages'] as List<dynamic>?)
        ?.map((e) => Part.fromJson(e as Map<String, dynamic>))
        .toList(),
    badge: json['badge'],
  );
}
