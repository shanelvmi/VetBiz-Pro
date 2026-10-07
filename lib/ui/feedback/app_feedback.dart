import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_breakpoints.dart';
import '../../theme/app_colors.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_motion.dart';
import '../../theme/app_palette.dart';
import '../../theme/app_text.dart';
import 'friendly_error.dart';

/// The one way the app tells the user what just happened
/// (docs/PHASE2_FEEDBACK_SPEC.md). Screens never call ScaffoldMessenger or
/// SnackBar themselves; guard rule R11 enforces that.
///
/// Needs no BuildContext: MaterialApp.scaffoldMessengerKey is
/// [messengerKey], so a call works after an `await`, and after the screen
/// that made it is gone. Every call is safe at any time and does nothing
/// if the app isn't up yet.
///
/// One message at a time, bottom-centre: a new one replaces the current
/// one, never queues behind it.
class AppFeedback {
  AppFeedback._();

  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  /// Something finished: past tense, the thing and what happened
  /// ("Product saved").
  static void success(String message, {String? detail}) =>
      _show(_Kind.success, message, detail: detail);

  /// Neutral information, or something in progress ("Recalculating…").
  static void info(String message, {String? detail}) => _show(_Kind.info, message, detail: detail);

  /// The user needs to do something next ("Select a client to …").
  static void warning(String message, {String? detail}) =>
      _show(_Kind.warning, message, detail: detail);

  /// Something failed. [title] says what ("Couldn't save the product"); the
  /// second line comes from [FriendlyError] unless [detail] is given. With
  /// [error], a Details action shows the technical text; with [onRetry], a
  /// Retry action. The raw error is always printed to the debug log.
  static void error(
    String title, {
    Object? error,
    StackTrace? stackTrace,
    String? detail,
    VoidCallback? onRetry,
  }) {
    if (error != null) {
      debugPrint('[FEEDBACK] $title: $error');
      if (stackTrace != null) debugPrint('$stackTrace');
    }
    _show(
      _Kind.error,
      title,
      detail: detail ?? (error == null ? null : FriendlyError.messageFor(error)),
      technical: error == null ? null : FriendlyError.detailsFor(error),
      actionLabel: onRetry == null ? null : 'Retry',
      onAction: onRetry,
    );
  }

  /// Something was moved to Trash and can be put back ("Client moved to
  /// Trash"). Only for soft deletes.
  static void undo(String message, {required VoidCallback onUndo}) =>
      _show(_Kind.undo, message, actionLabel: 'Undo', onAction: onUndo);

  static void _show(
    _Kind kind,
    String title, {
    String? detail,
    String? technical,
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    final messenger = messengerKey.currentState;
    final context = messengerKey.currentContext;
    if (messenger == null || context == null || !messenger.mounted) return;

    final compact = MediaQuery.sizeOf(context).width < AppBreakpoints.compact;
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: AppElevation.e0,
      padding: EdgeInsets.zero,
      // Exactly one of width / margin may be set on a floating SnackBar.
      width: compact ? null : AppSizes.toastMax,
      margin: compact ? const EdgeInsets.all(AppSpacing.s12) : null,
      // The card runs its own timer (so it can pause on hover); the
      // SnackBar itself never times out.
      persist: true,
      content: _FeedbackCard(
        kind: kind,
        title: title,
        detail: detail,
        technical: technical,
        actionLabel: actionLabel,
        onAction: onAction,
        onClose: () => messengerKey.currentState?.hideCurrentSnackBar(),
      ),
    ));
  }
}

enum _Kind { success, info, warning, error, undo }

extension on _Kind {
  Duration get duration => switch (this) {
        _Kind.success => AppMotion.toastSuccess,
        _Kind.info => AppMotion.toastInfo,
        _Kind.warning => AppMotion.toastWarning,
        _Kind.undo => AppMotion.toastUndo,
        _Kind.error => AppMotion.toastError,
      };

  IconData get glyph => switch (this) {
        _Kind.success => Icons.check,
        _Kind.info => Icons.info_outline,
        _Kind.warning => Icons.warning_amber_rounded,
        _Kind.error => Icons.error_outline,
        _Kind.undo => Icons.delete_outline,
      };

  /// (badge fill, glyph colour)
  (Color, Color) colors(AppColors c) => switch (this) {
        _Kind.success => (c.success.withValues(alpha: AppAlpha.a10), c.success),
        _Kind.info => (c.primary.withValues(alpha: AppAlpha.a10), c.primary),
        _Kind.warning => (c.warning.withValues(alpha: AppAlpha.a10), c.warning),
        _Kind.error => (c.danger.withValues(alpha: AppAlpha.a10), c.danger),
        _Kind.undo => (c.surfaceMuted, c.textSecondary),
      };
}

class _FeedbackCard extends StatefulWidget {
  final _Kind kind;
  final String title;
  final String? detail;
  final String? technical;
  final String? actionLabel;
  final VoidCallback? onAction;
  final VoidCallback onClose;

  const _FeedbackCard({
    required this.kind,
    required this.title,
    required this.onClose,
    this.detail,
    this.technical,
    this.actionLabel,
    this.onAction,
  });

  @override
  State<_FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<_FeedbackCard> {
  Timer? _timer;

  bool get _hasAction => widget.onAction != null || widget.technical != null;

  @override
  void initState() {
    super.initState();
    _startTimer();
  }

  @override
  void dispose() {
    // A replaced or closed message must not close the next one.
    _timer?.cancel();
    super.dispose();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer(widget.kind.duration, widget.onClose);
  }

  void _act() {
    _timer?.cancel();
    widget.onClose();
    widget.onAction?.call();
  }

  Future<void> _showDetails() async {
    _timer?.cancel();
    final text = widget.technical ?? '';
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Details'),
        // Dialogs need a width limit, or they stretch across a desktop.
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.dialogMd),
          child: SelectableText(text),
        ),
        actions: [
          TextButton(
            onPressed: () => Clipboard.setData(ClipboardData(text: text)),
            child: const Text('Copy'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
    if (mounted) _startTimer();
  }

  @override
  Widget build(BuildContext context) {
    final c = Theme.of(context).extension<AppColors>() ?? AppColors.fromTheme(AppColorTheme.kilimanjaro);
    final (badgeFill, glyphColor) = widget.kind.colors(c);
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final buttonStyle = TextButton.styleFrom(
      minimumSize: const Size(AppSizes.minTapTarget, AppSizes.minTapTarget),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s8),
    );

    final card = Material(
      color: c.surface,
      elevation: AppElevation.e2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.r12),
        side: BorderSide(color: c.borderStrong),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(AppSpacing.s12, AppSpacing.s8, AppSpacing.s4, AppSpacing.s8),
        child: Row(
          children: [
            Container(
              width: AppSizes.toastIcon,
              height: AppSizes.toastIcon,
              decoration: BoxDecoration(color: badgeFill, shape: BoxShape.circle),
              child: Icon(widget.kind.glyph, size: AppIconSize.i16, color: glyphColor),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: AppFontSize.f14,
                      fontWeight: AppFontWeight.semibold,
                      color: c.textPrimary,
                    ),
                  ),
                  if (widget.detail != null)
                    Text(
                      widget.detail!,
                      style: TextStyle(fontSize: AppFontSize.f13, color: c.textSecondary),
                    ),
                ],
              ),
            ),
            if (widget.technical != null)
              TextButton(
                style: buttonStyle.copyWith(foregroundColor: WidgetStatePropertyAll(c.textSecondary)),
                onPressed: _showDetails,
                child: const Text('Details'),
              ),
            if (widget.onAction != null)
              TextButton(
                style: buttonStyle.copyWith(foregroundColor: WidgetStatePropertyAll(c.primary)),
                onPressed: _act,
                child: Text(widget.actionLabel ?? '', style: const TextStyle(fontWeight: AppFontWeight.semibold)),
              ),
            IconButton(
              tooltip: 'Close',
              iconSize: AppIconSize.i16,
              constraints: const BoxConstraints(minWidth: AppSizes.minTapTarget, minHeight: AppSizes.minTapTarget),
              color: c.textSecondary,
              onPressed: () {
                _timer?.cancel();
                widget.onClose();
              },
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );

    return Semantics(
      liveRegion: true,
      label: widget.detail == null ? widget.title : '${widget.title}. ${widget.detail}',
      child: MouseRegion(
        // A message with an action stays while the pointer is over it, and
        // gets its full time again once the pointer leaves.
        onEnter: (_) {
          if (_hasAction) _timer?.cancel();
        },
        onExit: (_) {
          if (_hasAction) _startTimer();
        },
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: reduceMotion ? Duration.zero : AppMotion.fast,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(offset: Offset(0, AppSpacing.s12 * (1 - t)), child: child),
          ),
          child: card,
        ),
      ),
    );
  }
}
