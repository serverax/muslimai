import 'package:flutter/material.dart';

import '../design/sakina_luxury_theme.dart';

class SakinaTheme {
  static ThemeData buildLightTheme(bool isArabic) =>
      SakinaLuxuryTheme.build(isArabic);

  static ThemeData buildDarkTheme(bool isArabic) =>
      SakinaLuxuryTheme.build(isArabic);
}
