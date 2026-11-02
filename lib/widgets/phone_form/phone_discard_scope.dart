import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_layout.dart';

/// PH6 S6: on a phone, leaving a money form that holds entered data asks
/// first ("Discard this payment?", Keep editing or Discard); a clean form
/// leaves without asking. The Android back gesture, the browser's back and
/// the app bar's back arrow all ask (they go through Navigator.maybePop); a
/// save leaves with Navigator.pop, which never asks. Tablets and computers
/// keep today's forms: [child] alone.
///
/// The scope never lets the route go by itself (canPop false), and decides
/// when a pop is tried, so a change typed after the last rebuild still
/// counts: [isDirty] is asked then.
class PhoneDiscardScope extends StatelessWidget {
  /// What is being entered, the select key of phoneForm_discardTitle:
  /// sale, payment, client, transaction or visit.
  final String kind;
  final bool Function() isDirty;
  final Widget child;

  const PhoneDiscardScope({super.key, required this.kind, required this.isDirty, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!AppLayout.isPhone(context)) return child;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        if (!isDirty() || await confirmDiscard(context, kind) == true) {
          navigator.pop(result);
        }
      },
      child: child,
    );
  }

  /// The question, with Keep editing and Discard; true for Discard.
  static Future<bool?> confirmDiscard(BuildContext context, String kind) {
    final l10n = context.l10n;
    return showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.phoneForm_discardTitle(kind)),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: AppSizes.dialogSm),
          child: Text(l10n.phoneForm_discardBody),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(l10n.phoneForm_keepEditing)),
          TextButton(onPressed: () => Navigator.pop(dialogContext, true), child: Text(l10n.phoneForm_discard)),
        ],
      ),
    );
  }
}
