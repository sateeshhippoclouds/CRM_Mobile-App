// Dart imports:
import 'dart:math';

// Flutter imports:
import 'package:flutter/material.dart';

abstract class Palette {
  static const Color primary = Color(0xFF1A4FBA);
  static const Color primaryDark = Color(0xFF0D3285);
  static const Color primaryLight = Color(0xFF3D6FD4);
  static const Color secondary = Color(0xff2F2061);
  static const Color textGrey = Color(0xff716E6E);
  static const Color hintGrey = Color(0xff979797);
  static const Color textGrey2 = Color(0xff515151);
  static const Color textblack = Color(0xff0E0E0E);
  static const Color gradient1 = Color(0xff3c3c3c);
  static const Color border = Color(0xffCCCCCC);
  static const Color btColor = Color(0xff342060);
  static const Color white = Color(0xffFFFFFF);
  static const Color blue = Color(0xff70A1FF);

  static const Color scaffoldBackgroundColor = Color(0xffFFFFFF);
}

MaterialColor generateMaterialColor(Color color) {
  return MaterialColor(color.toARGB32(), {
    50: tintColor(color, 0.9),
    100: tintColor(color, 0.8),
    200: tintColor(color, 0.6),
    300: tintColor(color, 0.4),
    400: tintColor(color, 0.2),
    500: color,
    600: shadeColor(color, 0.1),
    700: shadeColor(color, 0.2),
    800: shadeColor(color, 0.3),
    900: shadeColor(color, 0.4),
  });
}

int _c(double channel) => (channel * 255.0).round().clamp(0, 255);

int tintValue(int value, double factor) {
  return max(0, min((value + ((255 - value) * factor)).round(), 255));
}

Color tintColor(Color color, double factor) {
  return Color.fromRGBO(
    tintValue(_c(color.r), factor),
    tintValue(_c(color.g), factor),
    tintValue(_c(color.b), factor),
    1,
  );
}

int shadeValue(int value, double factor) {
  return max(0, min(value - (value * factor).round(), 255));
}

Color shadeColor(Color color, double factor) {
  return Color.fromRGBO(
    shadeValue(_c(color.r), factor),
    shadeValue(_c(color.g), factor),
    shadeValue(_c(color.b), factor),
    1,
  );
}
