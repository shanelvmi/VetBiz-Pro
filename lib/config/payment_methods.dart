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

  /// Mixx by Yas's old name. No longer offered anywhere (the subscription
  /// form switched to Mixx by Yas in step 2C), but never removed: old
  /// subscription requests stored this key and must still display.
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

  /// The stored key's method, or null for a key the app doesn't know (an
  /// old or hand-edited record must still display, not crash).
  static PaymentMethod? fromKey(String? key) {
    for (final m in values) {
      if (m.key == key) return m;
    }
    return null;
  }
}
