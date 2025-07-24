class Freya {
  int? bubbleShowCnt;
  int? iconShow;

  Freya({this.bubbleShowCnt, this.iconShow});

  factory Freya.fromJson(Map<String, dynamic> json) => Freya(
    bubbleShowCnt: json['bubble_show_cnt'] as int?,
    iconShow: json['icon_show'] as int?,
  );
}
