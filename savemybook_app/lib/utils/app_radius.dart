import 'package:flutter/widgets.dart';

class AppRadius {
  const AppRadius._();

  static const double tag = 6;

  static const double chip = 8;

  static const double control = 12;

  static const double field = 14;

  static const double card = 16;

  static const double sheet = 20;

  static const double surface = 28;

  static BorderRadius get tagR => BorderRadius.circular(tag);
  static BorderRadius get chipR => BorderRadius.circular(chip);
  static BorderRadius get controlR => BorderRadius.circular(control);
  static BorderRadius get fieldR => BorderRadius.circular(field);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get sheetR => BorderRadius.circular(sheet);
  static BorderRadius get surfaceR => BorderRadius.circular(surface);
}
