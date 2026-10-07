/// Firestore collection names, typed once.
///
/// These name data that already exists: never rename one here without a
/// data migration and matching changes to firestore.rules, the indexes and
/// the Cloud Functions.
class Collections {
  Collections._();

  // Top level.
  static const String facilities = 'facilities';
  static const String users = 'users';
  static const String platformAdmins = 'platform_admins';
  static const String platformConfig = 'platform_config';
  static const String appConfig = 'app_config';
  static const String paymentSubmissions = 'payment_submissions';
  static const String publicAnnouncements = 'public_announcements';
  static const String promotions = 'promotions';
  static const String inviteCodes = 'inviteCodes';

  // Under a facility.
  static const String products = 'products';
  static const String batches = 'batches';
  static const String clients = 'clients';
  static const String debts = 'debts';
  static const String sales = 'sales';
  static const String services = 'services';
  static const String payments = 'payments';
  static const String transactions = 'transactions';
  static const String notifications = 'notifications';
  static const String activityLogs = 'activity_logs';
  static const String stockAdditions = 'stockAdditions';
  static const String stockAdjustments = 'stock_adjustments';
  static const String counters = 'counters';

  // Daily roll-ups.
  static const String dailySnapshots = 'dailySnapshots';
  static const String dailyStockSnapshots = 'dailyStockSnapshots';
  static const String dailySummaries = 'dailySummaries';
  static const String dailyTransactionSummaries = 'dailyTransactionSummaries';
  static const String dailyServiceSummaries = 'dailyServiceSummaries';
  static const String dailyCollections = 'dailyCollections';
  static const String dailyReports = 'dailyReports';

  // Archive and trash.
  static const String archivedSales = 'archived_sales';
  static const String archivedServices = 'archived_services';
  static const String trashSales = 'trash_sales';
  static const String trashServices = 'trash_services';
  static const String trashProducts = 'trash_products';
  static const String trashTransactions = 'trash_transactions';
}
