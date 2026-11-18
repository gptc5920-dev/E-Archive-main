import 'package:flutter/material.dart';

/// Central Poppins font helpers for the app.
class AppFonts {
  AppFonts._();

  static const String family = 'Poppins';
  static const List<String> fallbackFamilies = [
    'Segoe UI',
    'Arial',
    'sans-serif',
  ];

  static TextStyle poppins({
    TextStyle? textStyle,
    Color? color,
    double? fontSize,
    FontWeight? fontWeight,
    FontStyle? fontStyle,
    double? height,
    double? letterSpacing,
    TextDecoration? decoration,
  }) {
    return (textStyle ?? const TextStyle()).copyWith(
      fontFamily: family,
      fontFamilyFallback: fallbackFamilies,
      color: color,
      fontSize: fontSize,
      fontWeight: fontWeight,
      fontStyle: fontStyle,
      height: height,
      letterSpacing: letterSpacing,
      decoration: decoration,
    );
  }

  static TextStyle merge(TextStyle style) {
    return style.copyWith(
      fontFamily: family,
      fontFamilyFallback: fallbackFamilies,
    );
  }

  static TextTheme poppinsTextTheme(TextTheme base) {
    return base.apply(
      fontFamily: family,
      fontFamilyFallback: fallbackFamilies,
    );
  }
}
