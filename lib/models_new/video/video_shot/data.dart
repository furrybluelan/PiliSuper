class VideoShotData {
  String? pvdata;
  int? imgXLen;
  int? imgYLen;
  int? imgXSize;
  int? imgYSize;
  List<String>? image;
  List<int>? index;

  VideoShotData({
    this.pvdata,
    this.imgXLen,
    this.imgYLen,
    this.imgXSize,
    this.imgYSize,
    this.image,
    this.index,
  });

  factory VideoShotData.fromJson(Map<String, dynamic> json) => VideoShotData(
    pvdata: json["pvdata"],
    imgXLen: json["img_x_len"],
    imgYLen: json["img_y_len"],
    imgXSize: json["img_x_size"],
    imgYSize: json["img_y_size"],
    image: (json["image"] as List?)?.cast(),
    index: (json["index"] as List?)?.cast(),
  );
}
