import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/subscription_provider.dart';
import '../providers/user_role_provider.dart';
import '../screens/subscription/subscription_screen.dart';

/// Navigates to [destination] normally, unless the current facility's
/// subscription is locked - in that case shows a clear, honest
/// explanation. Admins get a direct path to the Subscription screen;
/// Assistants (who can't manage billing at all - Settings hides that
/// screen for them entirely) get pointed to their admin instead, rather
/// than a button that would just lead to another dead end.
Future<void> navigateOrShowLockedDialog(BuildContext context, Widget destination) async {
  final isLocked = Provider.of<SubscriptionProvider>(context, listen: false).isLocked;

  if (!isLocked) {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => destination));
    return;
  }

  final isAdmin = Provider.of<UserRoleProvider>(context, listen: false).isAdmin;

  if (!isAdmin) {
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Subscription Expired'),
        content: const Text(
          'This facility\'s subscription has expired, so new sales and services can\'t be '
          'recorded right now. You can still view all existing data. Please ask your admin '
          'to renew the subscription.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
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
      content: const Text(
        'Your subscription has expired, so new sales and services can\'t be recorded right now. '
        'You can still view all your existing data. Submit a payment to restore full access.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Go to Subscription'),
        ),
      ],
    ),
  );

  if (goToSubscription == true && context.mounted) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()));
  }
}
