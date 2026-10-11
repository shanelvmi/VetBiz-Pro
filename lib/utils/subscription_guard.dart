import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../l10n/l10n.dart';
import '../providers/subscription_provider.dart';
import '../providers/user_role_provider.dart';
import '../screens/subscription/subscription_screen.dart';
import '../theme/app_breakpoints.dart';
import '../theme/app_dimens.dart';
import '../theme/theme_context.dart';

// The dialog's buttons use the brand roles, the same ones add_sale_screen
// and add_edit_service_screen (the two callers) use, so they don't clash
// with whichever screen triggered it.

/// Fixed width on a wide screen, 85% of the screen below that.
double _dialogWidth(BuildContext context) => context.screenWidth > AppBreakpoints.dialogFixedWidth
    ? AppSizes.dialogXs
    : context.screenWidth * 0.85;

/// Navigates to [destination] normally, unless the current facility's
/// subscription is locked - in that case shows a clear, honest
/// explanation. Admins get a direct path to the Subscription screen;
/// Assistants (who can't manage billing at all - Settings hides that
/// screen for them entirely) get pointed to their admin instead, rather
/// than a button that would just lead to another dead end.
///
/// [onNavigate], if provided, replaces the default Navigator.push -
/// used to route through a screen's own modal-aware entry point (e.g.
/// showAddSaleScreen) instead of always pushing [destination] as a
/// plain full-screen route. Existing callers that don't pass this
/// keep their current behavior unchanged.
Future<void> navigateOrShowLockedDialog(
  BuildContext context,
  Widget destination, {
  Future<void> Function()? onNavigate,
}) async {
  final isLocked = Provider.of<SubscriptionProvider>(context, listen: false).isLocked;

  if (!isLocked) {
    if (onNavigate != null) {
      await onNavigate();
    } else {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
    }
    return;
  }

  final isAdmin = Provider.of<UserRoleProvider>(context, listen: false).isAdmin;

  if (!isAdmin) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.subscription_expiredTitle),
        content: SizedBox(
          width: _dialogWidth(context),
          child: Text(context.l10n.subscription_expiredAssistant),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: context.colors.primary),
            child: Text(context.l10n.common_ok),
          ),
        ],
      ),
    );
    return;
  }

  final goToSubscription = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.subscription_expiredTitle),
      content: SizedBox(
        width: _dialogWidth(context),
        child: Text(context.l10n.subscription_expiredAdmin),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: context.colors.primary),
          child: Text(context.l10n.common_cancel),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.hovered)) return context.colors.accent;
              return context.colors.primary;
            }),
            foregroundColor: WidgetStateProperty.all(context.colors.onPrimary),
          ),
          child: Text(context.l10n.subscription_goTo),
        ),
      ],
    ),
  );

  if (goToSubscription == true && context.mounted) {
    showSubscriptionScreen(context);
  }
}
