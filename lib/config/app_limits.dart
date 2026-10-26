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

  /// The full Notifications screen: the newest notifications it watches,
  /// then each "Load older" (NOTIF-2c; removed and expired items use up the
  /// window, so older ones must stay reachable).
  static const int notificationsWindow = 200;
  static const int notificationsOlderPage = 100;

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

  // Picked images (E4a-fix). storage.rules refuses an upload over 5 MB,
  // and a phone photo is often bigger, so every picker that feeds an
  // upload scales the image down at the source: image_picker keeps the
  // aspect ratio inside a square of the given side, in pixels.

  /// Profile photos (dashboard avatar, registration avatar).
  static const double avatarImageMaxSide = 512;

  /// Facility logos (facility_screen add and edit, business profile).
  static const double logoImageMaxSide = 1024;

  /// Product photos (add_edit_product_screen).
  static const double productImageMaxSide = 1280;

  /// Subscription payment proofs: large enough that the receipt text
  /// stays legible for the reviewer.
  static const double paymentProofImageMaxSide = 1600;

  /// JPEG quality (0-100) for every picked image.
  static const int pickedImageQuality = 85;

  /// The largest upload storage.rules accepts (`request.resource.size <=
  /// 5 * 1024 * 1024`). Keep the two equal.
  static const int maxUploadBytes = 5 * 1024 * 1024;

  /// The most entries each map of a person's notification state holds
  /// (firestore.rules, isValidNotificationState: `size() <= 2000`). Keep the
  /// two equal.
  static const int notificationStateMapMax = 2000;

  /// The words an owner types for a facility of type Other (typeDetail,
  /// RW2b2), trimmed. The server checks the same (TYPE_DETAIL_MIN and
  /// TYPE_DETAIL_MAX in functions/membership.js). Keep them equal.
  static const int typeDetailMin = 2;
  static const int typeDetailMax = 40;

  // Announcements v2 (AN1, docs/design/announcements_v2.md). The Platform
  // Admin form checks these; the login page (AN2) reads the poster ratio.

  /// A poster is picked scaled to this width (image_picker maxWidth), the
  /// 1600 x 900 the form's hint asks for.
  static const double posterWidth = 1600;

  /// Narrower than this and the poster blurs on a wide login page.
  static const int posterMinWidth = 1280;

  /// Posters are 16:9; a picked image may be off by this fraction (3 percent).
  static const double posterAspectRatio = 16 / 9;
  static const double posterRatioTolerance = 0.03;

  /// The largest poster storage.rules accepts (isPosterUpload: `size <=
  /// 1024 * 1024`). Keep the two equal.
  static const int posterMaxBytes = 1024 * 1024;

  /// Title, message and link button label lengths, trimmed. A poster's
  /// message is an optional caption, so it has no minimum.
  static const int announcementTitleMin = 2;
  static const int announcementTitleMax = 80;
  static const int announcementMessageMin = 2;
  static const int announcementMessageMax = 400;
  static const int posterMessageMax = 200;
  static const int announcementLinkLabelMin = 2;
  static const int announcementLinkLabelMax = 24;

  /// The most announcements the login page's Updates list holds (AN2).
  static const int updatesMaxSlides = 5;
}
