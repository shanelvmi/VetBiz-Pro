/// Page sizes and query caps, named for what they protect.
class AppLimits {
  AppLimits._();

  /// Cursor-paginated lists: sales, services, transactions, clients, debtors,
  /// past reports (sale_provider, service_provider, transaction_provider,
  /// cursor_paginated_list_controller, past_reports_screen).
  static const int pageSize = 25;

  /// Rows per page in the smaller in-screen tables (team, notifications,
  /// stock alerts, subscription history) - the starting choice.
  static const int tablePageSize = 10;

  /// Sales and services archives.
  static const int archivePageSize = 30;

  /// Platform admin lists (facilities directory, users).
  static const int platformAdminPageSize = 50;

  /// Product catalogue grid (product_catalog_service.dart).
  static const int productCatalogPageSize = 12;

  /// Upper bound on activity-log reads (activity_log_screen, and each
  /// clean-up pass in activity_log_retention).
  static const int ledgerQueryCap = 500;

  /// Recent activity on the dashboard.
  static const int recentActivityCount = 5;

  /// Notifications read for the dashboard bell.
  static const int dashboardNotifications = 50;

  /// A facility's subscription payment history, as the platform admin sees
  /// it (facility_detail_screen).
  static const int facilityPaymentHistory = 20;

  /// The clients list (ClientProvider.listenToClientsPaginated): the first
  /// page, then each "load more".
  static const int clientsFirstPage = 100;
  static const int clientsNextPage = 50;

  /// A facility's activity log in the facility screen: the full panel, and
  /// the short preview.
  static const int facilityActivityLog = 50;
  static const int facilityActivityPreview = 4;

  /// Recent sales shown for a facility (facility_screen).
  static const int facilityRecentSales = 8;

  /// Client name search results (client_provider name-prefix search).
  static const int clientSearchResults = 50;

  /// Candidates per word when looking for a duplicate client by name.
  static const int duplicateNameCandidates = 40;

  /// Candidates when looking for a duplicate client by phone.
  static const int duplicatePhoneCandidates = 5;

  /// A one-document read: "does any exist?", or the first in order (a
  /// client's oldest debt).
  static const int single = 1;

  /// "Is there more than one?" reads (a client's remaining debts).
  static const int moreThanOneCheck = 2;
}
