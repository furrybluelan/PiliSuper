class LoginLogItem {
  String ip;
  int? time;
  String timeAt;
  bool? status;
  int? type;
  String geo;

  LoginLogItem({
    required this.ip,
    this.time,
    required this.timeAt,
    this.status,
    this.type,
    required this.geo,
  });

  factory LoginLogItem.fromJson(Map<String, dynamic> json) => LoginLogItem(
    ip: json['ip'] ?? '',
    time: json['time'] as int?,
    timeAt: json['time_at'] ?? '',
    status: json['status'] as bool?,
    type: json['type'] as int?,
    geo: json['geo'] ?? '',
  );
}
