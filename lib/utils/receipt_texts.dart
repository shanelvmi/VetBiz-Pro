// The text printed on a receipt as the preview screens draw it (the
// receipt body: header, labels, totals, footer).
//
// Kept in English on purpose: receipts, PDFs and the thermal printer stay
// English until their language becomes a facility setting
// (docs/PHASE2_LOCALISATION_SPEC.md 2.8). Held here, apart from the preview
// screens, so the guard's R10 allowlist covers only this file and the
// screens' own buttons and panels are still checked.
// test/receipt_texts_test.dart pins every value.
class ReceiptTexts {
  ReceiptTexts._();

  // The brand line, drawn in two colours.
  static const String brandFirst = 'VetBiz ';
  static const String brandSecond = 'Pro';

  static String tin(String tin) => 'TIN: $tin';

  /// The facility's type after its name on receipts, PDFs and printed
  /// reports (RW2b2): an Other facility's own words when it has them, the
  /// English label of any other type, and nothing for a bare Other.
  static String facilityType(String? type, [String? typeDetail]) => type == null || type == 'Other' ? '' : type;
  static const String receiptNo = 'Receipt #';
  static const String date = 'Date';
  static const String customer = 'Customer';
  static const String providedBy = 'Provided By';
  static const String paymentMethod = 'Payment Method';
  static const String walkIn = 'Walk-in';
  static const String notAvailable = 'N/A';

  // Items table
  static const String colItemService = 'Item / Service';
  static const String colQty = 'Qty';
  static const String colUnitPrice = 'Unit Price';
  static const String colAmount = 'Amount';

  // Totals (Subtotal and Discount appear on sale receipts only)
  static const String subtotal = 'Subtotal';
  static const String discount = 'Discount';
  static const String total = 'TOTAL';
  static const String paid = 'Paid';
  static const String balance = 'Balance';

  // Payment status
  static const String partiallyPaid = 'Partially Paid';
  static const String balanceDue = 'Balance Due';
  static const String paidInFull = 'Paid in Full';

  // Footer
  static const String thankYou = 'Thank you for choosing us.';
  static String poweredBy(String appName) => 'Powered by $appName';

  // The text passed to the share sheet with the receipt image.
  static const String shareText = 'Receipt';
}
