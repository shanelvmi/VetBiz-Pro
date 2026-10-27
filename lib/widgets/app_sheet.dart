import 'package:flutter/material.dart';

import '../l10n/l10n.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/app_layout.dart';
import '../theme/app_motion.dart';
import '../theme/app_text.dart';
import '../theme/theme_context.dart';
import 'app_safe_area.dart';

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
    final width = (window.width * widthFactor).clamp(0, maxWidth).toDouble();
    var height = window.height * heightFactor;
    if (minHeight != null && height < minHeight!) height = minHeight!;
    if (maxHeight != null) height = height.clamp(0, maxHeight!).toDouble();
    return Size(width, height);
  }
}

/// Opens a form (or a page that behaves like one): a full page below
/// [AppBreakpoints.medium], a centred modal of [size] at that width and
/// wider. [builder] gets `isModal`. Returns what the form pops with.
Future<T?> showAdaptiveForm<T>(
  BuildContext context, {
  required String barrierLabel,
  required Widget Function(bool isModal) builder,
  AdaptiveFormSize size = AdaptiveFormSize.form,
}) {
  if (context.screenWidth < AppBreakpoints.medium) {
    return Navigator.of(context).push<T>(MaterialPageRoute(builder: (_) => builder(false)));
  }

  return showGeneralDialog<T>(
    context: context,
    barrierDismissible: true,
    barrierLabel: barrierLabel,
    barrierColor: context.colors.scrim.withValues(alpha: AppAlpha.a50),
    transitionDuration: AppMotion.normal,
    pageBuilder: (context, animation, secondaryAnimation) {
      final box = size.resolve(MediaQuery.of(context).size);
      return Center(
        child: SizedBox(
          width: box.width,
          height: box.height,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r16),
            child: Material(child: builder(true)),
          ),
        ),
      );
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(begin: AdaptiveFormMetrics.enterOffset, end: Offset.zero).animate(curved),
          child: ScaleTransition(
            scale: Tween<double>(begin: AdaptiveFormMetrics.enterScale, end: 1.0).animate(curved),
            child: child,
          ),
        ),
      );
    },
  );
}

/// Opens [builder]'s content where it suits the window:
/// - a phone: a bottom sheet (rounded top, drag handle, at most 92% of the
///   height, scrolls, rises above the keyboard, clear of the home
///   indicator); with [fullPage] (forms) a full page with a back arrow;
/// - a tablet or a computer: a dialog at most 560 wide and 88% high.
/// Returns what the content pops with.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  String? title,
  required WidgetBuilder builder,
  bool fullPage = false,
}) {
  if (!AppLayout.isPhone(context)) {
    return showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: AppSizes.dialogLg,
            maxHeight: MediaQuery.sizeOf(context).height * AppSheetMetrics.dialogMaxHeightFactor,
          ),
          child: _SheetContent(title: title, builder: builder, showClose: true),
        ),
      ),
    );
  }

  if (fullPage) {
    return Navigator.of(context).push<T>(MaterialPageRoute(
      builder: (context) => Scaffold(
        appBar: AppBar(title: title == null ? null : Text(title)),
        body: SingleChildScrollView(
          padding: EdgeInsets.only(bottom: AppSafeArea.bottomOf(context)),
          child: builder(context),
        ),
      ),
    ));
  }

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.r16)),
    ),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * AppSheetMetrics.sheetMaxHeightFactor,
    ),
    builder: (context) => Padding(
      // Above the keyboard when a field inside has focus.
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: _SheetContent(title: title, builder: builder, showClose: false),
    ),
  );
}

/// The title (and a Close button in a dialog) over the scrolling content.
class _SheetContent extends StatelessWidget {
  final String? title;
  final WidgetBuilder builder;
  final bool showClose;

  const _SheetContent({required this.title, required this.builder, required this.showClose});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (title != null || showClose)
          Padding(
            padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s8, AppSpacing.s8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title ?? '',
                    style: const TextStyle(fontSize: AppFontSize.f16, fontWeight: AppFontWeight.semibold),
                  ),
                ),
                if (showClose)
                  IconButton(
                    tooltip: context.l10n.common_close,
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
              ],
            ),
          ),
        Flexible(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.s16,
              AppSpacing.s8,
              AppSpacing.s16,
              AppSpacing.s16 + AppSafeArea.bottomOf(context),
            ),
            child: builder(context),
          ),
        ),
      ],
    );
  }
}
