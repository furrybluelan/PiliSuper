class Subtitle {
  String? lan;
  String? lanDoc;
  String? subtitleUrl;
  String? subtitleUrlV2;

  Subtitle({
    this.lan,
    this.lanDoc,
    this.subtitleUrl,
    this.subtitleUrlV2,
  });

  factory Subtitle.fromJson(Map<String, dynamic> json) => Subtitle(
    lan: json["lan"],
    lanDoc: json["lan_doc"],
    subtitleUrl: json["subtitle_url"],
    subtitleUrlV2: json["subtitle_url_v2"],
  );
}
