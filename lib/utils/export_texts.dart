// The text that goes INTO an exported file (CSV and xlsx): sheet names,
// title lines, header rows, fallback cell values and the share text.
//
// Kept in English on purpose: an exported file is a document, like a
// receipt or a PDF (docs/PHASE2_LOCALISATION_SPEC.md 2.8). Held here, apart
// from export_data_screen.dart, so the guard's R10 allowlist covers only
// this file and still checks every on-screen text of the screen.
// test/export_texts_test.dart pins every value: change none of them without
// meaning to change the exported files.
class ExportTexts {
  ExportTexts._();

  // Title lines above the tables.
  static String exportPeriod(String range) => 'Export Period: $range';
  static const String allRecords = 'All Records';
  static String dateRange(String start, String end) => '$start to $end';

  // The text passed to the share sheet with the file.
  static String shareText(String appName, String dataType) => '$appName export: $dataType';

  // The share text sent with the Active Debts CSV (debtors_screen.dart).
  static const String activeDebtsShareText = 'Active Debts Export';

  // Sales & Transactions
  static const String salesSheet = 'Sales';
  static String salesSubtitle(int active, int archived) => 'Sales ($active active, $archived archived)';
  static const List<String> salesHeaders = ['Date', 'Client', 'Total Amount', 'Total Paid', 'Status', 'Profit'];
  static const String transactionsSheet = 'Transactions';
  static const String transactionsSubtitle = 'Transactions';
  static const List<String> transactionsHeaders = ['Date', 'Type', 'Category', 'Description', 'Amount', 'Recorded By'];

  // Service Records
  static const String servicesSheet = 'Service Records';
  static String servicesSubtitle(int active, int archived) => 'Services ($active active, $archived archived)';
  static const List<String> servicesHeaders = [
    'Date', 'Client', 'Service', 'Category', 'Provided By', 'Total Amount', 'Total Paid', 'Status',
  ];

  // Product Inventory Catalog
  static const String productsSheet = 'Products';
  static String productsSubtitle(int rows) => 'Products ($rows rows, one per batch)';
  static const List<String> productsHeaders = [
    'Name', 'Category', 'Type', 'Batch No', 'Stock Qty', 'Sellable Qty', 'Buy Price', 'Sell Price', 'Expiry',
  ];

  // Client Directory & Balances
  static const String clientsSheet = 'Clients';
  static String clientsSubtitle(int rows) => 'Clients ($rows)';
  static const List<String> clientsHeaders = ['Name', 'Type', 'Phone', 'Address', 'Balance'];

  // Debtors / Outstanding Balances
  static const String debtorsSheet = 'Debtors';
  static String debtorsSubtitle(int rows) => 'Debtors ($rows outstanding)';
  static const List<String> debtorsHeaders = [
    'Client', 'Phone', 'Source', 'Amount Owed', 'Date Incurred', 'Last Updated',
  ];

  // Payments Ledger
  static const String paymentsSheet = 'Payments';
  static String paymentsSubtitle(int rows) => 'Payments ($rows)';
  static const List<String> paymentsHeaders = ['Date', 'Type', 'Client / Description', 'Amount'];
  // Keyed by the stored payment `source`.
  static const Map<String, String> paymentTypeBySource = {
    'sale': 'Sale payment',
    'service': 'Service payment',
    'debt_repayment': 'Debt repayment',
  };
  static const String paymentTypeFallback = 'Payment';
  static const String otherIncomeType = 'Other income';

  // Activity Log
  static const String activitySheet = 'Activity Log';
  static String activitySubtitle(int rows) => 'Activity Log ($rows entries)';
  static const List<String> activityHeaders = ['Date', 'User', 'Action Type', 'Description'];

  // Cell values written when a record has no value.
  static const String walkInClient = 'Walk-in';
  static const String notAvailable = 'N/A';
  static const String otherCategory = 'Other';
  static const String unknownClient = 'Unknown';
}
