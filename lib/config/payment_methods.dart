/// How a payment was made.
///
/// [key] is what is SAVED (in records, and as map keys in reports) and must
/// never change. What is shown on screen is [label], which is translated
/// later (step 2F); for now it is the same English text as the key.
enum PaymentMethod {
  cash('Cash'),
  mPesa('M-Pesa'),
  mixxByYas('Mixx by Yas'),
  haloPesa('HaloPesa'),
  airtelMoney('Airtel Money'),
  bankTransfer('Bank Transfer'),

  /// Offered only by the subscription payment form today, which still lists
  /// Tigo Pesa where the rest of the app lists Mixx by Yas. Kept so stored
  /// subscription requests still match. See design-open-questions.md.
  tigoPesa('Tigo Pesa');

  const PaymentMethod(this.key);

  final String key;

  String get label => key;

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

  /// The stored key's method, or null for a key the app doesn't know (an
  /// old or hand-edited record must still display, not crash).
  static PaymentMethod? fromKey(String? key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return null;
  }
}
