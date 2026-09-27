/// One row in the Payments screen's merged ledger - built from either
/// the `payments` collection (sale/service upfront payments, debt
/// repayments) or the `transactions` collection (entries with
/// type "other income"). Public specifically so PaymentProvider's
/// ledger-fetching logic, which needs to construct these, can live in
/// the provider rather than the screen - the screen's own former
/// _LedgerEntry stays as a type alias there for compatibility with its
/// existing display code.
class LedgerEntry {
  final String type; // 'sale' | 'service' | 'debt_repayment' | 'other_income'
  final double amount;
  final DateTime timestamp;
  final String? clientId;
  final String? clientName;
  final String? clientPhone;
  final String description;
  final String? paymentMethod;
  final String? paidById;
  final String? saleId;
  final String? serviceId;
  final String? debtId;
  // Tie-breaker for a deterministic sort when two entries share the
  // exact same timestamp - the source document's own id, since two
  // different documents can never collide on this.
  final String sortId;

  const LedgerEntry({
    required this.type,
    required this.amount,
    required this.timestamp,
    this.clientId,
    this.clientName,
    this.clientPhone,
    required this.description,
    this.paymentMethod,
    this.paidById,
    this.saleId,
    this.serviceId,
    this.debtId,
    required this.sortId,
  });
}
