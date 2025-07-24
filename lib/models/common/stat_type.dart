import 'package:flutter/material.dart' show IconData, Icons;

enum StatType {
  view(Icons.remove_red_eye_outlined),
  danmaku(Icons.subtitles_outlined),
  like(Icons.thumb_up_outlined),
  reply(Icons.comment_outlined),
  follow(Icons.favorite_border),
  play(Icons.play_circle_outlined),
  listen(Icons.headset_outlined);

  final IconData iconData;
  const StatType(this.iconData);
}
