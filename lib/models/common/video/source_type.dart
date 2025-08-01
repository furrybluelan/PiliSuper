enum SourceType {
  normal(-1),
  archive(1),
  watchLater(2),
  fav(3),
  playlist(3);

  final int mediaType;
  const SourceType(this.mediaType);
}
