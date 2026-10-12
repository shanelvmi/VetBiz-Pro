import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/utils/receipt_texts.dart';

// The expected text below was copied from service_receipt_preview_screen.dart
// before its receipt texts moved to ReceiptTexts: receipts stay English
// (docs/PHASE2_LOCALISATION_SPEC.md 2.8) and must read exactly as before.
void main() {
  test('receipt texts are unchanged', () {
    final lines = <String>[
      ReceiptTexts.brandFirst + ReceiptTexts.brandSecond,
      ReceiptTexts.tin('123-456-789'),
      ReceiptTexts.receiptNo,
      ReceiptTexts.date,
      ReceiptTexts.customer,
      ReceiptTexts.providedBy,
      ReceiptTexts.paymentMethod,
      ReceiptTexts.walkIn,
      ReceiptTexts.notAvailable,
      ReceiptTexts.colItemService,
      ReceiptTexts.colQty,
      ReceiptTexts.colUnitPrice,
      ReceiptTexts.colAmount,
      ReceiptTexts.total,
      ReceiptTexts.paid,
      ReceiptTexts.balance,
      ReceiptTexts.partiallyPaid,
      ReceiptTexts.balanceDue,
      ReceiptTexts.paidInFull,
      ReceiptTexts.thankYou,
      ReceiptTexts.poweredBy('VetBiz Pro'),
      ReceiptTexts.shareText,
    ];

    const expected = 'VetBiz Pro\n'
        'TIN: 123-456-789\n'
        'Receipt #\n'
        'Date\n'
        'Customer\n'
        'Provided By\n'
        'Payment Method\n'
        'Walk-in\n'
        'N/A\n'
        'Item / Service\n'
        'Qty\n'
        'Unit Price\n'
        'Amount\n'
        'TOTAL\n'
        'Paid\n'
        'Balance\n'
        'Partially Paid\n'
        'Balance Due\n'
        'Paid in Full\n'
        'Thank you for choosing us.\n'
        'Powered by VetBiz Pro\n'
        'Receipt';

    expect(lines.join('\n'), expected);
  });
}
