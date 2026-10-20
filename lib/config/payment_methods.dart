/// How a payment was made.
///
/// [key] is what is SAVED (in records, and as map keys in reports) and must
/// never change. What is shown on screen is its label in the current
/// language: `context.l10n.paymentMethodLabel(key)` (lib/l10n/stored_labels.dart).
enum PaymentMethod {
  cash('Cash'),
  mPesa('M-Pesa'),
  mixxByYas('Mixx by Yas'),
  haloPesa('HaloPesa'),
  airtelMoney('Airtel Money'),
  bankTransfer('Bank Transfer'),

  /// Mixx by Yas's old name. No longer offered anywhere (the subscription
  /// form switched to Mixx by Yas in step 2C), but never removed: old
  /// subscription requests stored this key and must still display.
  tigoPesa('Tigo Pesa');

  const PaymentMethod(this.key);

  final String key;

  /// Not a method: what is shown when nothing was paid, and what the daily
  /// report STORES as a sale row's method in that case (so it never changes).
  static const String onCredit = 'On Credit';

  /// The methods offered when recording money received (sales, services,
  /// repayments, other income) - kPaymentMethods, in the same order.
  static const List<PaymentMethod> recordable = [
    cash,
    mPesa,
    mixxByYas,
    haloPesa,
    airtelMoney,
    bankTransfer,
  ];

  /// The methods the subscription payment form offers, in its order. The
  /// same as [recordable] apart from order and HaloPesa, which the form has
  /// never offered.
  static const List<PaymentMethod> subscription = [
    mPesa,
    mixxByYas,
    airtelMoney,
    bankTransfer,
    cash,
  ];

  /// What a stored key is SHOWN, filtered and grouped as (R3, D5): Tigo Pesa
  /// is Mixx by Yas's old name, so a record stored as 'Tigo Pesa' reads as
  /// Mixx by Yas everywhere. The stored key itself never changes.
  static String shownKey(String key) => key == tigoPesa.key ? mixxByYas.key : key;

  /// The stored keys a filter on [shown] must match: Mixx by Yas finds the
  /// old Tigo Pesa records too.
  static List<String> storedKeysFor(String shown) =>
      shown == mixxByYas.key ? [mixxByYas.key, tigoPesa.key] : [shown];

  /// Amounts by stored key, summed under each key's [shownKey] (one Mixx by
  /// Yas row for both keys), in first-seen order. Display only: a report
  /// document keeps what it stored.
  static Map<String, double> combineShown(Iterable<Map<String, double>> byMethod) {
    final merged = <String, double>{};
    for (final map in byMethod) {
      for (final e in map.entries) {
        final key = shownKey(e.key);
        merged[key] = (merged[key] ?? 0) + e.value;
      }
    }
    return merged;
  }

  /// [combineShown] for one map.
  static Map<String, double> mergeShown(Map<String, double> byMethod) => combineShown([byMethod]);

  /// A filter's choices for the stored keys in a list: each shown key once, sorted.
  static List<String> shownChoices(Iterable<String> keys) => {for (final k in keys) shownKey(k)}.toList()..sort();

  /// The stored key's method, or null for a key the app doesn't know (an
  /// old or hand-edited record must still display, not crash).
  static PaymentMethod? fromKey(String? key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return null;
  }
}
