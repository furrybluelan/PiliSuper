import 'package:PiliPlus/models_new/fans/list.dart';

class FansData {
  List<FansItemModel>? list;
  String? offset;
  int? reVersion;
  int? total;

  FansData({this.list, this.offset, this.reVersion, this.total});

  factory FansData.fromJson(Map<String, dynamic> json) => FansData(
    list: (json['list'] as List<dynamic>?)
        ?.map((e) => FansItemModel.fromJson(e as Map<String, dynamic>))
        .toList(),
    offset: json['offset'] as String?,
    reVersion: json['re_version'] as int?,
    total: json['total'] as int?,
  );
}
