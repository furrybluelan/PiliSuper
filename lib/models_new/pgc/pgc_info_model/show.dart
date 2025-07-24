class Show {
  int? wideScreen;

  Show({this.wideScreen});

  factory Show.fromJson(Map<String, dynamic> json) => Show(
    wideScreen: json['wide_screen'] as int?,
  );
}
