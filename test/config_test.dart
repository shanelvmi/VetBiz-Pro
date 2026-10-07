import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_links.dart';
import 'package:vetbiz_pro/config/app_ranges.dart';
import 'package:vetbiz_pro/config/app_rules.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/config/payment_methods.dart';
import 'package:vetbiz_pro/config/restock_rules.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/services/usage_calculator_service.dart';
import 'package:vetbiz_pro/widgets/payment_method_selector.dart';

/// Config values that are still also typed where they are used today (until
/// step 2C moves those places over) must not drift apart in the meantime.
void main() {
  test('the stored payment keys never change, and kPaymentMethods lists them in order', () {
    expect(PaymentMethod.values.map((m) => m.key).toList(),
        ['Cash', 'M-Pesa', 'Mixx by Yas', 'HaloPesa', 'Airtel Money', 'Bank Transfer', 'Tigo Pesa']);
    expect(kPaymentMethods, ['Cash', 'M-Pesa', 'Mixx by Yas', 'HaloPesa', 'Airtel Money', 'Bank Transfer']);
    expect(PaymentMethod.onCredit, 'On Credit');
  });

  test('payment icons are the ones the old switch gave, for every key', () {
    expect(iconForPaymentMethod('Cash'), Icons.payments_outlined);
    for (final k in ['M-Pesa', 'Mixx by Yas', 'HaloPesa', 'Airtel Money']) {
      expect(iconForPaymentMethod(k), Icons.phone_android, reason: k);
    }
    expect(iconForPaymentMethod('Bank Transfer'), Icons.account_balance_outlined);
    // Old records: Tigo Pesa, and anything unknown, keep the generic icon.
    expect(iconForPaymentMethod('Tigo Pesa'), Icons.payment);
    expect(iconForPaymentMethod('Barter'), Icons.payment);
  });

  test('PaymentMethod keys are unique and round-trip; unknown is null', () {
    final keys = PaymentMethod.values.map((m) => m.key).toList();
    expect(keys.toSet().length, keys.length);
    for (final m in PaymentMethod.values) {
      expect(PaymentMethod.fromKey(m.key), m);
    }
    expect(PaymentMethod.fromKey('Barter'), isNull);
    expect(PaymentMethod.fromKey(null), isNull);
  });

  test('the subscription form offers Mixx by Yas, not Tigo Pesa, but old Tigo Pesa records still read', () {
    expect(PaymentMethod.subscription.map((m) => m.key).toList(),
        ['M-Pesa', 'Mixx by Yas', 'Airtel Money', 'Bank Transfer', 'Cash']);
    expect(PaymentMethod.subscription, isNot(contains(PaymentMethod.tigoPesa)));
    expect(PaymentMethod.fromKey('Tigo Pesa'), PaymentMethod.tigoPesa);
  });

  test('timeouts keep the values the code used (step 2C)', () {
    // (value, legacy milliseconds) pairs: several timeouts share a value, so
    // this is a list, not a map keyed by Duration.
    final pairs = <(Duration, int)>[
      (AppTimeouts.decideFirstScreen, 30000), (AppTimeouts.profileRead, 15000),
      (AppTimeouts.profileRecheck, 10000), (AppTimeouts.profileRecheckDelay, 700),
      (AppTimeouts.platformAdminRead, 10000), (AppTimeouts.facilityListRetry, 10000),
      (AppTimeouts.facilityListRetryDelay, 800), (AppTimeouts.unavailableRetryStep, 500),
      (AppTimeouts.authPoll, 2000), (AppTimeouts.startupRecoveryOffer, 8000),
      (AppTimeouts.loginSafetyNet, 6000), (AppTimeouts.roleLoad, 10000),
      (AppTimeouts.facilityLoad, 15000), (AppTimeouts.signOut, 10000),
      (AppTimeouts.teamLoadFallback, 8000), (AppTimeouts.proofUpload, 25000),
      (AppTimeouts.newRecordsPoll, 45000), (AppTimeouts.sessionCheck, 600000),
      (AppTimeouts.clockTick, 1000), (AppTimeouts.noticeExpiryTick, 60000),
      (AppTimeouts.presenceHeartbeat, 120000), (AppTimeouts.presenceOnlineWindow, 300000),
      (AppTimeouts.loginAnnouncementRotate, 6000), (AppTimeouts.platformAdminInactivity, 900000),
      (AppTimeouts.platformAdminInactivityWarning, 60000), (AppTimeouts.subscriptionNoticeSnooze, 7200000),
      (AppTimeouts.salesSummaryRefresh, 2000), (AppTimeouts.servicesSummaryRefresh, 500),
      (AppTimeouts.searchDebounce, 400), (AppTimeouts.clientPickerDebounce, 300),
      (AppTimeouts.inviteCodeLookupDebounce, 450), (AppTimeouts.facilityLookupDebounce, 500),
    ];
    for (final (actual, ms) in pairs) {
      expect(actual.inMilliseconds, ms);
    }
    expect(AppTimeouts.salesSummaryRetryDelays.map((d) => d.inSeconds), [0, 2, 3, 5]);
  });

  test('ranges keep the values the code used (step 2C)', () {
    expect(AppRanges.day.inDays, 1);
    expect(AppRanges.week.inDays, 7);
    expect(AppRanges.fortnight.inDays, 14);
    expect(AppRanges.month.inDays, 30);
    expect(AppRanges.year.inDays, 365);
    expect(AppRanges.defaultListRange.inDays, 30);
    expect(AppRanges.paymentsDefaultRange.inDays, 365);
    expect(AppRanges.instant.inSeconds, 1);
    expect(AppRanges.adminOverviewWindow.inDays, 90);
    expect(AppRanges.noticeLifetime.inDays, 2);
    expect(AppRanges.insightsTrendBack.inDays, 13);
    expect(AppRanges.exportLast7DaysBack.inDays, 6);
    expect(AppRanges.exportLast30DaysBack.inDays, 29);
    expect(AppRanges.archiveCutoffDays, 180);
    expect(AppRanges.archiveCutoff.inDays, 180);
    expect(AppRanges.archiveDefaultWindow.inDays, 90);
  });

  test('restock frequencies match UsageCalculatorService', () {
    expect(RestockRules.frequencies, UsageCalculatorService.restockFrequencyOptions);
    expect(RestockRules.defaultFrequency, UsageCalculatorService.defaultRestockFrequency);
  });

  test('attention days match SubscriptionProvider', () {
    expect(AppRules.subscriptionAttentionDays, SubscriptionProvider.attentionThresholdDays);
  });

  test('WhatsApp link matches the legacy builders', () {
    expect(AppLinks.whatsApp(AppContact.supportPhone).toString(), 'https://wa.me/255719199916');
    expect(AppLinks.whatsApp('+255 712-345 678', text: 'Habari, 5,000 & more').toString(),
        'https://wa.me/255712345678?text=${Uri.encodeComponent('Habari, 5,000 & more')}');
  });
}
