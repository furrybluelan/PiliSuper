import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

enum ThemeType {
  light('浅色'),
  dark('深色'),
  system('跟随系统');

  final String desc;
  const ThemeType(this.desc);

  ThemeMode get toThemeMode => switch (this) {
    ThemeType.light => ThemeMode.light,
    ThemeType.dark => ThemeMode.dark,
    ThemeType.system => ThemeMode.system,
  };

  Icon get icon => switch (this) {
    ThemeType.light => const Icon(MdiIcons.weatherSunny, size: 24),
    ThemeType.dark => const Icon(MdiIcons.weatherNight, size: 24),
    ThemeType.system => const Icon(MdiIcons.themeLightDark, size: 24),
  };
}
