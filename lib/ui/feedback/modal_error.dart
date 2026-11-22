import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

/// UX8: where a modal's errors go.
///
/// A form opened as a modal (showAdaptiveForm on PC and tablet) used to
/// report "fill all required fields" and failed saves through AppFeedback,
/// whose SnackBar is drawn on the page behind the modal, under its scrim.
/// While a [ModalErrorScope] is open, AppFeedback.warning and .error go to
/// the top-most one instead, as a [ModalErrorBanner] at the top of the
/// modal, and not behind it. Messages and when they are raised are
/// unchanged. Success, info and undo stay toasts (they are usually said
/// after the modal closed).
class ModalErrorScope extends StatefulWidget {
  const ModalErrorScope({super.key, required this.child});

  final Widget child;

  static final _open = <_ModalErrorScopeState>[];

  /// Shows [title] (and [detail]) in the top-most open scope. False when no
  /// modal is open: the caller shows its toast as before.
  static bool show(String title, {String? detail, required bool isError}) {
    for (final scope in _open.reversed) {
      if (scope.mounted) {
        scope._set(_ModalError(title, detail, isError));
        return true;
      }
    }
    return false;
  }

  @override
  State<ModalErrorScope> createState() => _ModalErrorScopeState();
}

class _ModalError {
  const _ModalError(this.title, this.detail, this.isError);
  final String title;
  final String? detail;
  final bool isError;
}

class _ModalErrorScopeState extends State<ModalErrorScope> {
  _ModalError? _error;

  void _set(_ModalError? error) => setState(() => _error = error);

  @override
  void initState() {
    super.initState();
    ModalErrorScope._open.add(this);
  }

  @override
  void dispose() {
    ModalErrorScope._open.remove(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (error != null)
          ModalErrorBanner(
            title: error.title,
            detail: error.detail,
            isError: error.isError,
            onClose: () => _set(null),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}

/// The banner itself: a tinted strip with the message and a close button.
/// Usable on its own where a modal shows an error inline.
class ModalErrorBanner extends StatelessWidget {
  const ModalErrorBanner({super.key, required this.title, this.detail, this.isError = true, this.onClose});

  final String title;
  final String? detail;
  final bool isError;
  final VoidCallback? onClose;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final tone = isError ? colors.danger : colors.warning;
    return Semantics(
      liveRegion: true,
      container: true,
      child: Container(
        key: const ValueKey('modal-error-banner'),
        padding: const EdgeInsets.fromLTRB(AppSpacing.s16, AppSpacing.s4, AppSpacing.s4, AppSpacing.s4),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: AppAlpha.a10),
          border: Border(bottom: BorderSide(color: tone)),
        ),
        child: Row(
          children: [
            Icon(isError ? Icons.error_outline : Icons.warning_amber_rounded, color: tone, size: AppIconSize.i20),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title,
                        style: TextStyle(color: colors.textPrimary, fontSize: AppFontSize.f14, fontWeight: AppFontWeight.semibold)),
                    if (detail != null && detail!.isNotEmpty)
                      Text(detail!, style: TextStyle(color: colors.textSecondary, fontSize: AppFontSize.f13)),
                  ],
                ),
              ),
            ),
            if (onClose != null)
              IconButton(
                key: const ValueKey('modal-error-close'),
                tooltip: context.l10n.common_close,
                onPressed: onClose,
                icon: Icon(Icons.close, size: AppIconSize.i18, color: colors.textSecondary),
                constraints: const BoxConstraints(minWidth: AppSizes.minTapTarget, minHeight: AppSizes.minTapTarget),
              ),
          ],
        ),
      ),
    );
  }
}
