class Choice {
  int? id;
  String? platformAction;
  String? nativeAction;
  String? condition;
  int? cid;
  String? option;
  int? isDefault;

  Choice({
    this.id,
    this.platformAction,
    this.nativeAction,
    this.condition,
    this.cid,
    this.option,
    this.isDefault,
  });

  factory Choice.fromJson(Map<String, dynamic> json) => Choice(
    id: json['id'] as int?,
    platformAction: json['platform_action'] as String?,
    nativeAction: json['native_action'] as String?,
    condition: json['condition'] as String?,
    cid: json['cid'] as int?,
    option: json['option'] as String?,
    isDefault: json['is_default'] as int?,
  );
}
