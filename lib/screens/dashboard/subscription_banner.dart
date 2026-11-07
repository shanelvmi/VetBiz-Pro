import 'package:flutter/material.dart';

import '../../config/app_timeouts.dart';
import '../../l10n/l10n.dart';
import '../../providers/subscription_provider.dart';
import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

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
}) {
  final needsAttention = status == SubscriptionStatus.grace ||
      status == SubscriptionStatus.locked ||
      ((status == SubscriptionStatus.trial || status == SubscriptionStatus.active) &&
          daysRemaining != null &&
          daysRemaining <= SubscriptionProvider.attentionThresholdDays);
  if (!needsAttention && !inCalmTrial) return null;
  if (status == SubscriptionStatus.locked) return const SubscriptionBannerState(SubscriptionBannerKind.locked);
  if (status == SubscriptionStatus.grace) return const SubscriptionBannerState(SubscriptionBannerKind.grace);
  if (inCalmTrial) return SubscriptionBannerState(SubscriptionBannerKind.calmTrial, daysRemaining);
  if (status == SubscriptionStatus.trial) return SubscriptionBannerState(SubscriptionBannerKind.trialEnding, daysRemaining);
  return SubscriptionBannerState(SubscriptionBannerKind.paidEnding, daysRemaining);
}

/// Today's full sentence (the wide pill, and the assistant's Details).
String subscriptionBannerSentence(AppLocalizations l, SubscriptionBannerState state) {
  final days = state.days;
  return switch (state.kind) {
    SubscriptionBannerKind.locked => l.subscription_expiredReadOnly,
    SubscriptionBannerKind.grace => l.subscription_expiredGrace,
    // A legacy facility with no trial or subscription date reaches the calm
    // trial with no days: an open-ended trial, never "null days".
    SubscriptionBannerKind.calmTrial => days != null ? l.subscription_freeTrialDaysLeft(days) : l.subscription_onFreeTrial,
    SubscriptionBannerKind.trialEnding => days != null ? l.subscription_trialExpiresIn(days) : l.subscription_trialActive,
    SubscriptionBannerKind.paidEnding => days != null ? l.subscription_expiresIn(days) : l.subscription_active,
  };
}

/// The phone banner's short line.
String subscriptionBannerShortText(AppLocalizations l, SubscriptionBannerState state) {
  final days = state.days;
  return switch (state.kind) {
    SubscriptionBannerKind.locked => l.subscription_bannerLocked,
    SubscriptionBannerKind.grace => l.subscription_bannerGrace,
    SubscriptionBannerKind.calmTrial => days != null ? l.subscription_bannerTrialDays(days) : l.subscription_onFreeTrial,
    SubscriptionBannerKind.trialEnding => days != null ? l.subscription_bannerTrialEnds(days) : l.subscription_trialActive,
    SubscriptionBannerKind.paidEnding => days != null ? l.subscription_bannerEnds(days) : l.subscription_active,
  };
}

/// The banner's snooze, as before PH8a: the close button hides it for
/// AppTimeouts.subscriptionNoticeSnooze (2 hours), whatever the state, read-
/// only included. In memory only: a new sign-in builds a new dashboard, so it
/// shows again.
///
/// Snoozed rather than dismissed for good: it is a real warning that access
/// is about to change, so a one-time "X" that never came back could mean
/// someone forgets and is locked out with no further reminder.
class SubscriptionBannerSnooze {
  DateTime? _until;

  bool isSnoozed(DateTime now) => _until != null && now.isBefore(_until!);

  void snooze(DateTime now) => _until = now.add(AppTimeouts.subscriptionNoticeSnooze);
}

/// PH8a: the slim banner at the top of every phone tab (PhoneShell places
/// it): an icon, the short line, the action (Renew, or Details in the calm
/// trial, opening Subscription for an admin; Details, the full sentence and who manages it,
/// for an assistant) and the snooze. The status is in the text and the icon;
/// its fill is the status role, slightly see-through (PH8a-fix: it floats
/// over the content).
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

  Future<void> _details(BuildContext context) {
    final l = context.l10n;
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.subscription_title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subscriptionBannerSentence(l, state)),
            const SizedBox(height: AppSpacing.s12),
            Text(l.subscription_bannerAdminManages, style: TextStyle(color: context.colors.textMuted)),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(context), child: Text(l.common_ok))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l = context.l10n;
    final (role, icon) = switch (state.kind) {
      SubscriptionBannerKind.locked => (colors.danger, Icons.lock_outline),
      SubscriptionBannerKind.calmTrial => (colors.info, Icons.workspace_premium_outlined),
      _ => (colors.warning, Icons.warning_amber_rounded),
    };
    final action = isAdmin
        ? (state.kind == SubscriptionBannerKind.calmTrial ? l.common_details : l.subscription_renew)
        : l.common_details;
    // PH8a-fix: it floats over the content (PhoneShell places it), so the
    // fill is the role itself, slightly see-through, and the ink is the one
    // that reads on it over any content (AppColors.bannerInk). A live region:
    // a screen reader announces it when it comes or its state changes.
    final ink = colors.bannerInk;
    final radius = BorderRadius.circular(PhoneBannerMetrics.overlayRadius);
    return Semantics(
      container: true,
      liveRegion: true,
      child: DecoratedBox(
        key: const ValueKey('phone-subscription-banner-fill'),
        decoration: BoxDecoration(
          color: role.withValues(alpha: PhoneBannerMetrics.overlayAlpha),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: colors.shadow.withValues(alpha: PhoneBannerMetrics.shadowAlpha),
              blurRadius: PhoneBannerMetrics.shadowBlur,
              offset: const Offset(0, PhoneBannerMetrics.shadowOffsetY),
            ),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          borderRadius: radius,
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            top: false,
            bottom: false,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                  start: PhoneBannerMetrics.paddingStart, top: PhoneBannerMetrics.paddingV, bottom: PhoneBannerMetrics.paddingV),
              child: Row(
                children: [
                  Icon(icon, color: ink, size: PhoneBannerMetrics.icon),
                  const SizedBox(width: PhoneBannerMetrics.gap),
                  Expanded(
                    child: Text(
                      subscriptionBannerShortText(l, state),
                      key: const ValueKey('phone-subscription-banner-text'),
                      maxLines: PhoneBannerMetrics.maxLines,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: PhoneBannerMetrics.text, fontWeight: AppFontWeight.semibold, color: ink),
                    ),
                  ),
                  TextButton(
                    onPressed: isAdmin ? onOpenSubscription : () => _details(context),
                    style: TextButton.styleFrom(
                      foregroundColor: ink,
                      padding: const EdgeInsets.symmetric(horizontal: PhoneBannerMetrics.actionPaddingH),
                      textStyle: const TextStyle(fontSize: PhoneBannerMetrics.text, fontWeight: AppFontWeight.bold),
                    ),
                    child: Text(action),
                  ),
                  // Snoozes rather than dismisses for good (SubscriptionBannerSnooze).
                  IconButton(
                    tooltip: l.common_close,
                    onPressed: onSnooze,
                    icon: Icon(Icons.close, color: ink),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
