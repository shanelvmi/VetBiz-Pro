import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../providers/subscription_provider.dart';

/// PH8a: what the subscription banner tells, from the same rules as the
/// dashboard's pill since before PH8a (audited in the PH8a ledger row):
/// read-only (locked), the grace days, the calm trial, and the last 7 days of
/// a trial or a paid subscription. After a trial ends the status is grace or
/// locked like a paid one, so those two always read "subscription".
enum SubscriptionBannerKind { locked, grace, calmTrial, trialEnding, paidEnding }

class SubscriptionBannerState {
  final SubscriptionBannerKind kind;

  /// The days left (the calm trial may have none: an open-ended trial).
  final int? days;

  const SubscriptionBannerState(this.kind, [this.days]);

  @override
  bool operator ==(Object other) => other is SubscriptionBannerState && other.kind == kind && other.days == days;

  @override
  int get hashCode => Object.hash(kind, days);

  @override
  String toString() => 'SubscriptionBannerState($kind, $days)';
}

/// The banner's state, or null when it has nothing to tell.
SubscriptionBannerState? subscriptionBannerFor({
  required SubscriptionStatus status,
  required int? daysRemaining,
  required bool inCalmTrial,
}) =>
    throw UnimplementedError();

/// Today's full sentence (the wide pill, and the assistant's Details).
String subscriptionBannerSentence(AppLocalizations l, SubscriptionBannerState state) => throw UnimplementedError();

/// The phone banner's short line.
String subscriptionBannerShortText(AppLocalizations l, SubscriptionBannerState state) => throw UnimplementedError();

/// The banner's snooze, as before PH8a: the close button hides it for
/// AppTimeouts.subscriptionNoticeSnooze (2 hours), whatever the state, read-
/// only included. In memory only: a new sign-in builds a new dashboard, so it
/// shows again.
class SubscriptionBannerSnooze {
  bool isSnoozed(DateTime now) => throw UnimplementedError();
  void snooze(DateTime now) => throw UnimplementedError();
}

/// PH8a: the slim banner at the top of every phone tab (PhoneShell places
/// it): an icon, the short line in the status colour's text, the action
/// (Renew or View Plans opening Subscription for an admin; Details, the full
/// sentence and "Ask your admin", for an assistant) and the snooze.
class PhoneSubscriptionBanner extends StatelessWidget {
  final SubscriptionBannerState state;
  final bool isAdmin;
  final VoidCallback onOpenSubscription;
  final VoidCallback onSnooze;

  const PhoneSubscriptionBanner({
    super.key,
    required this.state,
    required this.isAdmin,
    required this.onOpenSubscription,
    required this.onSnooze,
  });

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
