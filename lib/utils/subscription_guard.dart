import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../providers/user_role_provider.dart';
import '../screens/subscription/subscription_screen.dart';

// Matches the exact values already used in add_sale_screen.dart and
// add_edit_service_screen.dart - the two screens that actually call
// this utility - so the dialog's own button colors don't clash with
// whichever screen triggered it.
const Color _primaryDeepGreen = Color(0xFF2F5D62);
const Color _warmAmber = Color(0xFFFFB200);

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
        title: const Text('Subscription Expired'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
          child: const Text(
            'This facility\'s subscription has expired, so new sales and services can\'t be '
            'recorded right now. You can still view all existing data. Please ask your admin '
            'to renew the subscription.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(foregroundColor: _primaryDeepGreen),
            child: const Text('OK'),
          ),
        ],
      ),
    );
    return;
  }

  final goToSubscription = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Subscription Expired'),
      content: SizedBox(
        width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
        child: const Text(
          'Your subscription has expired, so new sales and services can\'t be recorded right now. '
          'You can still view all your existing data. Submit a payment to restore full access.',
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          style: TextButton.styleFrom(foregroundColor: _primaryDeepGreen),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ButtonStyle(
            backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
              if (states.contains(WidgetState.hovered)) return _warmAmber;
              return _primaryDeepGreen;
            }),
            foregroundColor: WidgetStateProperty.all(Colors.white),
          ),
          child: const Text('Go to Subscription'),
        ),
      ],
    ),
  );

  if (goToSubscription == true && context.mounted) {
    showSubscriptionScreen(context);
  }
}
