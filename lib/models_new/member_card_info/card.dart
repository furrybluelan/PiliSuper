import 'package:PiliPlus/models/model_avatar.dart';

class Card {
  String? mid;
  String? name;
  String? face;
  int? fans;
  int? attention;
  BaseOfficialVerify? officialVerify;
  Vip? vip;

  Card({
    this.mid,
    this.name,
    this.face,
    this.fans,
    this.attention,
    this.officialVerify,
    this.vip,
  });

  factory Card.fromJson(Map<String, dynamic> json) => Card(
    mid: json['mid'] as String?,
    name: json['name'] as String?,
    face: json['face'] as String?,
    fans: json['fans'] as int?,
    attention: json['attention'] as int?,
    officialVerify: json['official_verify'] == null
        ? null
        : BaseOfficialVerify.fromJson(
            json['official_verify'] as Map<String, dynamic>,
          ),
    vip: json['vip'] == null
        ? null
        : Vip.fromJson(json['vip'] as Map<String, dynamic>),
  );
}
