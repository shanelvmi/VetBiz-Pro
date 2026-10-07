import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Font sizes, named after their value so moving a screen onto them is exact
/// (`fontSize: 12.5` -> `AppFontSize.f12_5`). The ladder is today's sizes,
/// unchanged; merging near-duplicates is a separate, reviewed step (2R).
class AppFontSize {
  AppFontSize._();

  static const double f9 = 9;
  static const double f10 = 10;
  static const double f10_5 = 10.5;
  static const double f11 = 11;
  static const double f11_5 = 11.5;
  static const double f12 = 12;
  static const double f12_5 = 12.5;
  static const double f13 = 13;
  static const double f13_5 = 13.5;
  static const double f14 = 14;
  static const double f14_5 = 14.5;
  static const double f15 = 15;
  static const double f16 = 16;
  static const double f17 = 17;
  static const double f18 = 18;
  static const double f19 = 19;
  static const double f20 = 20;
  static const double f22 = 22;

  /// Display sizes: rare, but kept exact.
  static const double f24 = 24;
  static const double f28 = 28;
}

class AppFontWeight {
  AppFontWeight._();

  static const FontWeight regular = FontWeight.normal;
  static const FontWeight medium = FontWeight.w500;
  static const FontWeight semibold = FontWeight.w600;

  /// `FontWeight.w700` is the same weight and maps here too.
  static const FontWeight bold = FontWeight.bold;
  static const FontWeight extraBold = FontWeight.w800;
}

/// Role styles for NEW code, so new screens don't add to the size ladder.
/// The migration of existing screens uses [AppFontSize] instead, so nothing
/// shifts. Colours come from the theme: pass `context.colors`.
class AppText {
  AppText._();

  static TextStyle caption(AppColors c) =>
      TextStyle(fontSize: AppFontSize.f11, color: c.textPrimary);
  static TextStyle bodySm(AppColors c) =>
      TextStyle(fontSize: AppFontSize.f12_5, color: c.textPrimary);
  static TextStyle body(AppColors c) =>
      TextStyle(fontSize: AppFontSize.f13, color: c.textPrimary);
  static TextStyle bodyLg(AppColors c) =>
      TextStyle(fontSize: AppFontSize.f14, color: c.textPrimary);
  static TextStyle label(AppColors c) => TextStyle(
      fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold, color: c.textPrimary);
  static TextStyle title(AppColors c) =>
      TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.bold, color: c.textPrimary);
  static TextStyle headline(AppColors c) =>
      TextStyle(fontSize: AppFontSize.f20, fontWeight: AppFontWeight.bold, color: c.textPrimary);
  static TextStyle display(AppColors c) =>
      TextStyle(fontSize: AppFontSize.f28, fontWeight: AppFontWeight.bold, color: c.textPrimary);
}
