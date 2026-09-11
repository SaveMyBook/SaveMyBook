import 'package:flutter/widgets.dart';

/// 圓角尺度。全 App 只用這幾階，不要現場寫數字。
///
/// 之前散出 20 種不同的值（1、2、7、9、11、13、17、22…），
/// 相鄰元件差一兩個像素，看起來就是「每塊各做各的」。
class AppRadius {
  const AppRadius._();

  /// 標籤、小色塊。
  static const double tag = 6;

  /// 膠囊按鈕、徽章、輸入框內的小控件。
  static const double chip = 8;

  /// 一般按鈕、輸入框。
  static const double control = 12;

  /// 主要按鈕、表單欄位。
  static const double field = 14;

  /// 卡片。
  static const double card = 16;

  /// 對話框、底部面板。
  static const double sheet = 20;

  /// 大面積表面（啟動畫面的 logo、全螢幕卡片）。
  static const double surface = 28;

  static BorderRadius get tagR => BorderRadius.circular(tag);
  static BorderRadius get chipR => BorderRadius.circular(chip);
  static BorderRadius get controlR => BorderRadius.circular(control);
  static BorderRadius get fieldR => BorderRadius.circular(field);
  static BorderRadius get cardR => BorderRadius.circular(card);
  static BorderRadius get sheetR => BorderRadius.circular(sheet);
  static BorderRadius get surfaceR => BorderRadius.circular(surface);
}
