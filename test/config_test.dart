import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/config/app_links.dart';
import 'package:vetbiz_pro/config/app_ranges.dart';
import 'package:vetbiz_pro/config/app_rules.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/config/payment_methods.dart';
import 'package:vetbiz_pro/config/restock_rules.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/services/usage_calculator_service.dart';
import 'package:vetbiz_pro/utils/client_duplicate_matcher.dart';
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

  test('the app name is unchanged', () {
    expect(AppInfo.name, 'VetBiz Pro');
    expect(AppInfo.shortName, 'VetBiz');
  });

  test('restock rules keep their exact numbers, all four frequencies', () {
    expect(RestockRules.frequencies, ['Weekly', 'Every 2 Weeks', 'Monthly', 'Rarely']);
    expect(RestockRules.defaultFrequency, 'Every 2 Weeks');
    final expected = <String, (int, int, int)>{
      'Weekly': (2, 5, 7),
      'Every 2 Weeks': (3, 7, 14),
      'Monthly': (5, 10, 21),
      'Rarely': (7, 14, 30),
    };
    expect(RestockRules.dayCountsByFrequency.keys.toSet(), expected.keys.toSet());
    expected.forEach((freq, days) {
      final d = RestockRules.dayCountsByFrequency[freq]!;
      expect((d.shelfMinDays, d.lowStockDays, d.reorderDays), days, reason: freq);
    });
    expect(RestockRules.usageLookbackDays, 30);
    expect(RestockRules.usageLookback.inDays, 30);
    expect(RestockRules.minUnitsForConfidence, 3);
    // The service's public names still say the same thing.
    expect(UsageCalculatorService.restockFrequencyOptions, RestockRules.frequencies);
    expect(UsageCalculatorService.defaultRestockFrequency, RestockRules.defaultFrequency);
    expect(UsageCalculatorService.lookbackDays, 30);
    expect(UsageCalculatorService.minUnitsForConfidence, 3);
  });

  test('attention days match SubscriptionProvider', () {
    expect(AppRules.subscriptionAttentionDays, SubscriptionProvider.attentionThresholdDays);
  });

  group('links are exactly the URLs the screens built by hand', () {
    // The old expressions, copied from the screens they replaced.
    String oldDashboardWhatsApp(String whatsapp) {
      final digitsOnly = whatsapp.replaceAll(RegExp(r'[^0-9+]'), '').replaceAll('+', '');
      return Uri.parse('https://wa.me/$digitsOnly').toString();
    }

    (String, String) oldDebtorLinks(String phone, String message) {
      final digitsOnly = phone.replaceAll(RegExp(r'[^0-9+]'), '');
      final encodedMessage = Uri.encodeComponent(message);
      return (
        Uri.parse('https://wa.me/${digitsOnly.replaceAll('+', '')}?text=$encodedMessage').toString(),
        Uri.parse('sms:$digitsOnly?body=$encodedMessage').toString(),
      );
    }

    const phones = ['+255 712-345 678', '0712345678', '+255719199916', '255 (712) 345.678', ''];
    const messages = ['Hi Asha, you owe Tsh 5,000 & more. Asante!', '', 'Karibu: 100% / ?=#'];

    test('WhatsApp (dashboard contact)', () {
      for (final p in phones) {
        expect(AppLinks.whatsApp(p).toString(), oldDashboardWhatsApp(p), reason: p);
      }
    });

    test('WhatsApp and SMS debt reminders', () {
      for (final p in phones) {
        for (final m in messages) {
          final (wa, sms) = oldDebtorLinks(p, m);
          expect(AppLinks.whatsApp(p, text: m).toString(), wa, reason: '$p / $m');
          expect(AppLinks.sms(p, body: m).toString(), sms, reason: '$p / $m');
        }
      }
    });

    test('tel and mailto pass the value through', () {
      for (final p in phones) {
        expect(AppLinks.tel(p).toString(), Uri.parse('tel:$p').toString(), reason: p);
      }
      expect(AppLinks.mailto('a.b@example.com').toString(), Uri.parse('mailto:a.b@example.com').toString());
    });

    test('Settings support links', () {
      expect(AppContact.supportPhone, '+255719199916');
      expect(AppContact.supportEmail, 'shanelvmi@gmail.com');
      expect(AppLinks.whatsApp(AppContact.supportPhone).toString(), 'https://wa.me/255719199916');
      expect(AppLinks.tel(AppContact.supportPhone).toString(), Uri.parse('tel:+255719199916').toString());
      expect(AppLinks.mailto(AppContact.supportEmail).toString(), 'mailto:shanelvmi@gmail.com');
    });

    test('phone variants for the duplicate check are unchanged', () {
      expect(ClientDuplicateMatcher.phoneVariants('0712345678').toSet(), {
        '0712345678', '712345678', '255712345678', '+255712345678', '00255712345678',
        '712 345 678', '0712 345 678', '0712-345-678', '0712.345.678',
        '255 712 345 678', '+255 712 345 678', '+255-712-345-678',
      });
      expect(ClientDuplicateMatcher.phoneKey('+255 712 345 678'), '712345678');
    });
  });
}
