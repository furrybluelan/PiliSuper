import 'package:PiliPlus/models_new/follow/list.dart';

class FollowData {
  List<FollowItemModel>? list;
  int? reVersion;
  int? total;

  FollowData({this.list, this.reVersion, this.total});

  factory FollowData.fromJson(Map<String, dynamic> json) => FollowData(
    list: (json['list'] as List<dynamic>?)
        ?.map((e) => FollowItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    reVersion: json['re_version'] as int?,
    total: json['total'] as int?,
  );
}
