import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/utils/export_texts.dart';

// The expected text below was copied from export_data_screen.dart before
// its file texts moved to ExportTexts: the exported files must stay
// byte-identical (docs/FIXES.md item 2). The headers are joined the way
// the CSV renderer joins them (none needs quoting).
void main() {
  test('exported file texts are unchanged', () {
    final lines = <String>[
      ExportTexts.exportPeriod(ExportTexts.dateRange('2026-01-01', '2026-01-31')),
      ExportTexts.exportPeriod(ExportTexts.allRecords),
      ExportTexts.shareText('VetBiz Pro', 'Sales & Transactions'),
      ExportTexts.salesSheet,
      ExportTexts.salesSubtitle(2, 1),
      ExportTexts.salesHeaders.join(','),
      ExportTexts.transactionsSheet,
      ExportTexts.transactionsSubtitle,
      ExportTexts.transactionsHeaders.join(','),
      ExportTexts.servicesSheet,
      ExportTexts.servicesSubtitle(3, 0),
      ExportTexts.servicesHeaders.join(','),
      ExportTexts.productsSheet,
      ExportTexts.productsSubtitle(4),
      ExportTexts.productsHeaders.join(','),
      ExportTexts.clientsSheet,
      ExportTexts.clientsSubtitle(5),
      ExportTexts.clientsHeaders.join(','),
      ExportTexts.debtorsSheet,
      ExportTexts.debtorsSubtitle(6),
      ExportTexts.debtorsHeaders.join(','),
      ExportTexts.paymentsSheet,
      ExportTexts.paymentsSubtitle(7),
      ExportTexts.paymentsHeaders.join(','),
      ExportTexts.paymentTypeBySource.entries.map((e) => '${e.key}=${e.value}').join(';'),
      ExportTexts.paymentTypeFallback,
      ExportTexts.otherIncomeType,
      ExportTexts.activitySheet,
      ExportTexts.activitySubtitle(8),
      ExportTexts.activityHeaders.join(','),
      ExportTexts.walkInClient,
      ExportTexts.notAvailable,
      ExportTexts.otherCategory,
      ExportTexts.unknownClient,
    ];

    const expected = 'Export Period: 2026-01-01 to 2026-01-31\n'
        'Export Period: All Records\n'
        'VetBiz Pro export: Sales & Transactions\n'
        'Sales\n'
        'Sales (2 active, 1 archived)\n'
        'Date,Client,Total Amount,Total Paid,Status,Profit\n'
        'Transactions\n'
        'Transactions\n'
        'Date,Type,Category,Description,Amount,Recorded By\n'
        'Service Records\n'
        'Services (3 active, 0 archived)\n'
        'Date,Client,Service,Category,Provided By,Total Amount,Total Paid,Status\n'
        'Products\n'
        'Products (4 rows, one per batch)\n'
        'Name,Category,Type,Batch No,Stock Qty,Sellable Qty,Buy Price,Sell Price,Expiry\n'
        'Clients\n'
        'Clients (5)\n'
        'Name,Type,Phone,Address,Balance\n'
        'Debtors\n'
        'Debtors (6 outstanding)\n'
        'Client,Phone,Source,Amount Owed,Date Incurred,Last Updated\n'
        'Payments\n'
        'Payments (7)\n'
        'Date,Type,Client / Description,Amount\n'
        'sale=Sale payment;service=Service payment;debt_repayment=Debt repayment\n'
        'Payment\n'
        'Other income\n'
        'Activity Log\n'
        'Activity Log (8 entries)\n'
        'Date,User,Action Type,Description\n'
        'Walk-in\n'
        'N/A\n'
        'Other\n'
        'Unknown';

    expect(lines.join('\n'), expected);
  });
}
