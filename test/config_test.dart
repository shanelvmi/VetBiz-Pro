import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_links.dart';
import 'package:vetbiz_pro/config/app_rules.dart';
import 'package:vetbiz_pro/config/payment_methods.dart';
import 'package:vetbiz_pro/config/restock_rules.dart';
import 'package:vetbiz_pro/providers/subscription_provider.dart';
import 'package:vetbiz_pro/services/usage_calculator_service.dart';
import 'package:vetbiz_pro/widgets/payment_method_selector.dart';

/// Config values that are still also typed where they are used today (until
/// step 2C moves those places over) must not drift apart in the meantime.
void main() {
  test('PaymentMethod.recordable is kPaymentMethods, same order', () {
    expect(PaymentMethod.recordable.map((m) => m.key).toList(), kPaymentMethods);
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
