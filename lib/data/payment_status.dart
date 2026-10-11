/// A sale's or service's payment status, as stored on `paymentStatus` (written
/// by Sale.toMap and Service.toMap, and queried with `isEqualTo` by the Sales
/// and Services status filters). The values never change; what is shown is
/// their label (`context.l10n.paymentStatusLabel`).
class PaymentStatus {
  PaymentStatus._();

  static const String paid = 'Paid';
  static const String partial = 'Partial';
  static const String unpaid = 'Unpaid';

  /// In the order the status filters offer them.
  static const List<String> values = [paid, partial, unpaid];

  /// The status of [amountPaid] against [total]: the one rule the records and
  /// the screens use.
  static String of(num amountPaid, num total) => amountPaid >= total ? paid : (amountPaid > 0 ? partial : unpaid);
}
