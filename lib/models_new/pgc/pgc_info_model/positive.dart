class Positive {
  int? id;
  String? title;

  Positive({this.id, this.title});

  factory Positive.fromJson(Map<String, dynamic> json) => Positive(
    id: json['id'] as int?,
    title: json['title'] as String?,
  );
}
