import 'package:flutter/material.dart';

import '../theme/app_dimens.dart';

// PH2b S4 (docs/design/phone_foundations.md): one sheet helper and one form
// helper instead of a copy per screen.

/// How big a form opened by [showAdaptiveForm] is on a wide window. The
/// presets keep the exact numbers of the copies they replaced.
class AdaptiveFormSize {
  final double widthFactor;
  final double maxWidth;
  final double heightFactor;

  /// Never shorter than this (the forms that hold a 480 px picker).
  final double? minHeight;

  /// Never taller than this (the shorter forms).
  final double? maxHeight;

  const AdaptiveFormSize({
    required this.widthFactor,
    required this.maxWidth,
    required this.heightFactor,
    this.minHeight,
    this.maxHeight,
  });

  /// 60% wide up to 940, 88% high and at least 480: Add Sale, Record
  /// Payment, Add/Edit Product, Add Batch, View Batches, Insights,
  /// Subscription, Edit Profile.
  static const form = AdaptiveFormSize(
    widthFactor: AdaptiveFormMetrics.widthFactor,
    maxWidth: AdaptiveFormMetrics.maxWidth,
    heightFactor: AdaptiveFormMetrics.heightFactor,
    minHeight: AdaptiveFormMetrics.minHeight,
  );

  /// As [form] but at most 820 high: Add Client, Add Service, Add
  /// Transaction.
  static const formCapped = AdaptiveFormSize(
    widthFactor: AdaptiveFormMetrics.widthFactor,
    maxWidth: AdaptiveFormMetrics.maxWidth,
    heightFactor: AdaptiveFormMetrics.heightFactor,
    maxHeight: AdaptiveFormMetrics.cappedMaxHeight,
  );

  /// 72% wide up to 1100, 90% high and at least 480: the full report.
  static const reportFull = AdaptiveFormSize(
    widthFactor: AdaptiveFormMetrics.reportWidthFactor,
    maxWidth: AdaptiveFormMetrics.reportFullMaxWidth,
    heightFactor: AdaptiveFormMetrics.reportHeightFactor,
    minHeight: AdaptiveFormMetrics.minHeight,
  );

  /// As [reportFull] but up to 900 wide: the report review.
  static const reportReview = AdaptiveFormSize(
    widthFactor: AdaptiveFormMetrics.reportWidthFactor,
    maxWidth: AdaptiveFormMetrics.reportReviewMaxWidth,
    heightFactor: AdaptiveFormMetrics.reportHeightFactor,
    minHeight: AdaptiveFormMetrics.minHeight,
  );

  /// 85% of the window both ways, up to AppSizes.contentLg wide: the
  /// activity log.
  static const activityLog = AdaptiveFormSize(
    widthFactor: AdaptiveFormMetrics.activityFactor,
    maxWidth: AppSizes.contentLg,
    heightFactor: AdaptiveFormMetrics.activityFactor,
  );

  /// The modal's size in a [window].
  Size resolve(Size window) {
    throw UnimplementedError();
  }
}

/// Opens a form: a full page below AppBreakpoints.medium, a centred modal
/// of [size] from it. (PH2b stub.)
Future<T?> showAdaptiveForm<T>(
  BuildContext context, {
  required String barrierLabel,
  required Widget Function(bool isModal) builder,
  AdaptiveFormSize size = AdaptiveFormSize.form,
}) {
  throw UnimplementedError();
}

/// A bottom sheet (or a full page) on phones, a dialog elsewhere. (PH2b stub.)
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  bool fullPage = false,
}) {
  throw UnimplementedError();
}
