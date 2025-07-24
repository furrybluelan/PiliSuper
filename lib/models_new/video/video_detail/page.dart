import 'package:PiliPlus/models_new/video/video_detail/dimension.dart';

class Part {
  int? cid;
  int? page;
  String? from;
  String? pagePart;
  int? duration;
  String? vid;
  String? weblink;
  Dimension? dimension;
  int? ctime;
  String? firstFrame;
  String? badge;

  Part({
    this.cid,
    this.page,
    this.from,
    this.pagePart,
    this.duration,
    this.vid,
    this.weblink,
    this.dimension,
    this.ctime,
    this.firstFrame,
    this.badge,
  });

  factory Part.fromJson(Map<String, dynamic> json) => Part(
    cid: json['cid'] as int?,
    page: json['page'] as int?,
    from: json['from'] as String?,
    pagePart: json['part'] as String?,
    duration: json['duration'] as int?,
    vid: json['vid'] as String?,
    weblink: json['weblink'] as String?,
    dimension: json['dimension'] == null
        ? null
        : Dimension.fromJson(json['dimension'] as Map<String, dynamic>),
    ctime: json['ctime'] as int?,
    firstFrame: json['first_frame'] as String?,
    badge: json["badge"],
  );
}
