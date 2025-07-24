class Stat {
  num coins;
  int? danmakus;
  int favorite;
  int? favorites;
  String? followText;
  int likes;
  int? reply;
  int? share;
  int? views;
  int? vt;

  Stat({
    required this.coins,
    this.danmakus,
    required this.favorite,
    this.favorites,
    this.followText,
    required this.likes,
    this.reply,
    this.share,
    this.views,
    this.vt,
  });

  factory Stat.fromJson(Map<String, dynamic> json) => Stat(
    coins: json["coins"] ?? 0,
    danmakus: json["danmakus"],
    favorite: json["favorite"] ?? 0,
    favorites: json["favorites"],
    followText: json["follow_text"],
    likes: json["likes"] ?? 0,
    reply: json["reply"],
    share: json["share"],
    views: json["views"],
    vt: json["vt"],
  );
}
