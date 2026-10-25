import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../providers/product_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';

import '../../services/auth_service.dart';
import '../../services/session_validity_service.dart';
import '../../services/dashboard_summary_service.dart';
import '../../services/sales_summary_service.dart';
import '../../services/notification_feed.dart';
import '../../utils/upload_size_check.dart';

import '../../widgets/summary_card.dart';
import '../../widgets/initials_avatar.dart';
import '../../widgets/profile/profile_menu_button.dart';

import '../products/products_screen.dart';
import '../clients/clients_screen.dart';
import '../services/services_screen.dart';
import '../sales/sales_screen.dart';
import '../transactions/transactions_screen.dart';
import '../reports/view_reports_screen.dart';
import '../facilities/facility_screen.dart';
import '../settings/settings_screen.dart';
import '../platform_admin/platform_admin_home_screen.dart';
import '../activity/activity_log_screen.dart';
import '../debtors/debtors_screen.dart';
import '../payments/payments_screen.dart';
import '../../providers/subscription_provider.dart';
import '../../models/promotion.dart';
import '../../providers/ui_settings_provider.dart';
import '../../providers/user_role_provider.dart';
import '../../utils/merged_query_stream.dart';
import '../subscription/subscription_screen.dart';
import 'dashboard_panels.dart';
import 'sales_revenue_chart.dart';
import 'notifications_screen.dart';
import '../../utils/subscription_guard.dart';
import '../../utils/force_logout.dart';
import '../../utils/notification_seen_tracker.dart';
import '../store/stockstore_screen.dart';
import '../admin/manage_assistants_screen.dart';
import '../sales/add_sale_screen.dart';
import '../products/add_edit_product_screen.dart';
import '../services/add_edit_service_screen.dart';
import '../register_screen.dart';
import '../../data/collections.dart';
import '../../data/upload_content_types.dart';
import '../../data/fields.dart';
import '../../data/user_role.dart';
import '../../data/user_status.dart';
import '../../config/money.dart';
import '../../config/app_limits.dart';
import '../../config/app_timeouts.dart';
import '../../config/app_ranges.dart';
import '../../config/app_date_format.dart';
import '../../config/app_links.dart';
import '../../config/app_info.dart';
import '../../theme/app_dimens.dart';
import '../../theme/theme_context.dart';
import '../../theme/app_breakpoints.dart';
import '../../ui/feedback/app_feedback.dart';
import '../../theme/app_text.dart';
import '../../theme/app_motion.dart';
import '../../l10n/l10n.dart';

// The light ink on the brand areas (sidebar items and labels, the logo
// plate, the profile drawer buttons). In light it stays `background`, value
// for value as before; in dark `background` is the dark page colour, which
// would vanish on brandSurface, so it is onBrandSurface (white) there
// (dark_mode.md section 4, K2).
Color _onBrandInk(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? context.colors.onBrandSurface : context.colors.background;

class DrawerHoverItem extends StatefulWidget {
  final IconData icon;
  final String title;
  final VoidCallback onTap;
  final bool isCollapsed;

  const DrawerHoverItem({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.isCollapsed = false,
  });

  @override
  State<DrawerHoverItem> createState() => _DrawerHoverItemState();
}

class _DrawerHoverItemState extends State<DrawerHoverItem> {
  bool _hovered = false;
  // The hover fill's fade (was 200 ms) and the collapsed-label tooltip wait
  // (300 ms), snapped to the nearest motion step (parked_values.md C1, C2).
  static const Duration _hoverFade = AppMotion.normal;
  static const Duration _tooltipWait = AppMotion.slow;

  @override
  Widget build(BuildContext context) {
    final row = LayoutBuilder(
      builder: (context, constraints) {
        // Ramps from fully transparent to fully opaque over the same
        // width range the sidebar itself passes through mid-animation -
        // constraints.maxWidth updates every frame as the parent
        // AnimatedContainer's width transitions, so this fade is
        // genuinely synchronized with that motion rather than the
        // label instantly popping in/out the moment isCollapsed flips,
        // which is what made the toggle feel abrupt.
        final labelOpacity = ((constraints.maxWidth - 100) / 60).clamp(0.0, 1.0);
        final canShowLabel = labelOpacity > 0.01;
        return Row(
          mainAxisAlignment: canShowLabel ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            Icon(widget.icon, color: _onBrandInk(context)),
            if (canShowLabel) ...[
              const SizedBox(width: AppSpacing.s16),
              Expanded(
                child: Opacity(
                  opacity: labelOpacity,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: _onBrandInk(context),
                      fontWeight: AppFontWeight.medium,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );

    final content = Padding(
      padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? AppSpacing.s4 : AppSpacing.s8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: _hoverFade,
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s10, horizontal: widget.isCollapsed ? AppSpacing.s12 : AppSpacing.s16),
            decoration: BoxDecoration(
              color: _hovered ? context.colors.sidebarHover : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadius.r8),
            ),
            child: row,
          ),
        ),
      ),
    );

    // Tooltip only when collapsed - the label is already visible
    // otherwise, so a tooltip on top of visible text would be
    // redundant.
    if (!widget.isCollapsed) return content;
    return Tooltip(
      message: widget.title,
      waitDuration: _tooltipWait,
      child: content,
    );
  }
}

/// A small pulsing dot - used on the notifications bell specifically for
/// something genuinely new since it was last opened (a fresh urgent
/// announcement, a newly-registered pending assistant), distinct from
/// the plain steady dot used for ongoing conditions like low stock.
/// Stops blinking the moment Notifications is opened, since that marks
/// everything as viewed.
class _BlinkingDot extends StatefulWidget {
  // One color just blinks in place, unchanged from before. More than
  // one cycles through them in sequence - red for something urgent,
  // blue for "you're on a trial", amber for an active promotion -
  // rather than only ever showing whichever one happened to be
  // checked first.
  final List<Color> colors;
  const _BlinkingDot({this.colors = const [Colors.redAccent]});

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  Timer? _colorCycleTimer;
  int _colorIndex = 0;

  @override
  void initState() {
    super.initState();
    _colorCycleTimer = Timer.periodic(const Duration(milliseconds: 1400), (_) {
      if (mounted) setState(() => _colorIndex = (_colorIndex + 1) % widget.colors.length);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _colorCycleTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentColor = widget.colors[_colorIndex % widget.colors.length];
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        width: 9,
        height: 9,
        decoration: BoxDecoration(color: currentColor, shape: BoxShape.circle),
      ),
    );
  }
}

class _DashboardSearchResult {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  _DashboardSearchResult({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });
}

class HoverFab extends StatefulWidget {
  final String heroTag;
  final IconData icon;
  final String label;
  final Color color;
  final Color hoverColor;
  final VoidCallback onPressed;

  const HoverFab({
    super.key,
    required this.heroTag,
    required this.icon,
    required this.label,
    required this.color,
    required this.hoverColor,
    required this.onPressed,
  });

  @override
  State<HoverFab> createState() => _HoverFabState();
}

class _HoverFabState extends State<HoverFab> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AppMotion.fast,
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..scaleByDouble(0.97, 0.97, 0.97, 1.0)) // Slight shrink on hover
            : Matrix4.identity(),
        child: FloatingActionButton.extended(
          heroTag: widget.heroTag,
          backgroundColor: _hovered ? widget.hoverColor : widget.color,
          icon: Icon(widget.icon, color: context.colors.onPrimary),
          label: Text(widget.label, style: TextStyle(color: context.colors.onPrimary)),
          onPressed: widget.onPressed,
        ),
      ),
    );
  }
}

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> with WidgetsBindingObserver {
  // The subscription banner's fade-and-scale switch (was 550 ms), snapped to
  // the nearest motion step (parked_values.md C3).
  static const Duration _bannerSwitch = AppMotion.slowest;
  // Space under the profile panel so the Logout button does not cover it: a
  // size, kept exact (D9).
  static const double _logoutClearance = 80;

  final user = FirebaseAuth.instance.currentUser;
  late final userDoc = FirebaseFirestore.instance.collection(Collections.users).doc(user?.uid);

  Uint8List? _profileBytes; // Profile picture in memory
  final ImagePicker _picker = ImagePicker();

  String selectedFilter = 'Today';

  // Same cached check as settings_screen.dart's own _isPlatformAdmin -
  // the "Platform Admin" nav item lives here now instead, so this
  // screen needs the same check.
  bool? _isPlatformAdminCache;

  Future<bool> _isPlatformAdmin() async {
    if (_isPlatformAdminCache != null) return _isPlatformAdminCache!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection(Collections.platformAdmins).doc(user.uid).get();
    _isPlatformAdminCache = doc.exists;
    return _isPlatformAdminCache!;
  }

  // Whether there's something genuinely new since Notifications was
  // last opened on this device (a fresh urgent announcement, or a
  // newly-registered pending assistant) - drives the bell's blink,
  // separate from hasStockAlerts/hasUrgentAnnouncement (which drive its
  // steady dot, since those reflect ongoing conditions rather than
  // one-off new arrivals).
  DateTime? _lastNotificationsViewedAt;
  bool _hasNewUrgentSinceViewed = false;
  bool _hasNewPendingAssistantSinceViewed = false;
  StreamSubscription<QuerySnapshot>? _urgentWatchSub;
  StreamSubscription<QuerySnapshot>? _pendingWatchSub;

  // Detects a remote "Log Out of All Devices" - see
  // SessionValidityService for why this needs an explicit periodic
  // check rather than something that would just happen automatically.
  Timer? _sessionCheckTimer;

  // Measures the bell's actual on-screen position for the desktop
  // dropdown - it sits in different places depending on screen size
  // (AppBar leading on wide screens, actions on narrow ones), so a
  // fixed/assumed position wouldn't anchor correctly in both.
  final GlobalKey _bellKey = GlobalKey();

  // The bell reads the same feed as the Notifications dropdown (NOTIF-2c), so
  // its red dot follows MY read state and a promotion I removed stops its
  // accent. One per facility and person, created once (a new stream on every
  // build would reset it).
  NotificationFeedController? _bellFeed;
  String? _bellFeedKey;

  NotificationFeedController? _bellFeedFor(String facilityId) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final key = (facilityId.isEmpty || uid == null) ? null : '$facilityId/$uid';
    if (key == _bellFeedKey) return _bellFeed;
    _bellFeed?.dispose();
    _bellFeedKey = key;
    if (key == null) return _bellFeed = null;
    final subscription = Provider.of<SubscriptionProvider>(context, listen: false);
    final role = Provider.of<UserRoleProvider>(context, listen: false);
    return _bellFeed = NotificationFeedController(
      firestore: FirebaseFirestore.instance,
      facilityId: facilityId,
      uid: uid!,
      isAdmin: () => role.isAdmin,
      subscription: () => SubscriptionFacts.of(subscription),
      subscriptionChanges: Listenable.merge([subscription, role]),
      window: AppLimits.dashboardNotifications,
    )..start();
  }
  static const Duration _sessionCheckInterval = AppTimeouts.sessionCheck;

  // Persisted per device (not synced) so the collapsed/expanded choice
  // survives between sessions, same reasoning as the notification
  // "last viewed" tracker - this is purely a personal display
  // preference, not something that needs to follow the account
  // anywhere else.
  bool _isDrawerCollapsed = false;

  Future<void> _loadDrawerCollapsedState() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isDrawerCollapsed = prefs.getBool('drawer_collapsed') ?? false);
    }
  }

  Future<void> _toggleDrawerCollapsed() async {
    final newValue = !_isDrawerCollapsed;
    setState(() => _isDrawerCollapsed = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('drawer_collapsed', newValue);
  }

  // Dismissing the subscription notice snoozes it rather than hiding it
  // permanently - this is still a real warning that access is about to
  // change, so a one-time "X" that never comes back could mean someone
  // forgets entirely and gets locked out with no further reminder.
  // Deliberately kept in-memory only, not persisted to
  // SharedPreferences - a fresh login creates a brand-new
  // DashboardScreen instance (the old one is disposed on logout), so
  // this naturally resets and reappears on every new login, on top of
  // the 2-hour timer resurfacing it within a single continuous session.
  static const Duration _subscriptionSnoozeDuration = AppTimeouts.subscriptionNoticeSnooze;
  DateTime? _subscriptionSnoozedUntil;

  void _snoozeSubscriptionBanner() {
    setState(() => _subscriptionSnoozedUntil = DateTime.now().add(_subscriptionSnoozeDuration));
  }

  // The pill deliberately doesn't appear the instant Dashboard loads,
  // even if the subscription already needs attention - it waits a
  // beat first, so its entrance is something someone actually notices
  // happening, rather than one more thing appearing simultaneously
  // with everything else on the page.
  bool _subscriptionPillDelayPassed = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _sessionCheckTimer = Timer.periodic(
      _sessionCheckInterval,
      (_) {
        SessionValidityService.checkAndHandleRevocation();
        _checkStillAssignedToActiveFacility();
      },
    );
    _loadDrawerCollapsedState();
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) setState(() => _subscriptionPillDelayPassed = true);
    });
    // Firebase caches emailVerified and doesn't update it automatically
    // once someone clicks the link in their email - has to be
    // explicitly refreshed to find out if it changed since last login.
    Provider.of<AuthService>(context, listen: false).refreshEmailVerifiedStatus();
    _watchForNewNotifications();
  }

  Future<void> _watchForNewNotifications() async {
    final lastViewed = await NotificationSeenTracker.getLastViewedAt();
    if (!mounted) return;
    setState(() => _lastNotificationsViewedAt = lastViewed);

    _urgentWatchSub = FirebaseFirestore.instance
        .collection(Collections.publicAnnouncements)
        .where('urgent', isEqualTo: true)
        .snapshots()
        .listen((snapshot) {
      final isNew = _lastNotificationsViewedAt != null &&
          snapshot.docs.any((doc) {
            final data = doc.data();
            if (data['hidden'] == true) return false;
            final ts = data['timestamp'];
            return ts is Timestamp && ts.toDate().isAfter(_lastNotificationsViewedAt!);
          });
      if (mounted) setState(() => _hasNewUrgentSinceViewed = isNew);
    });

    final isAdmin = Provider.of<UserRoleProvider>(context, listen: false).isAdmin;
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (isAdmin && facilityId != null) {
      _pendingWatchSub = FirebaseFirestore.instance
          .collection(Collections.users)
          .where(Fields.role, isEqualTo: UserRole.assistant.key)
          .where(Fields.status, isEqualTo: UserStatus.pending.key)
          .where('facilityIds', arrayContains: facilityId)
          .snapshots()
          .listen((snapshot) {
        final isNew = _lastNotificationsViewedAt != null &&
            snapshot.docs.any((doc) {
              final ts = doc.data()[Fields.createdAt];
              return ts is Timestamp && ts.toDate().isAfter(_lastNotificationsViewedAt!);
            });
        if (mounted) setState(() => _hasNewPendingAssistantSinceViewed = isNew);
      });
    }
  }

  // Called when returning from Notifications, since opening it marks
  // "viewed now" on that screen - re-fetching here lets the blink stop
  // immediately on return, instead of waiting for the next full
  // dashboard reload to notice the update.
  Future<void> _refreshNotificationsViewedState() async {
    final lastViewed = await NotificationSeenTracker.getLastViewedAt();
    if (mounted) {
      setState(() {
        _lastNotificationsViewedAt = lastViewed;
        _hasNewUrgentSinceViewed = false;
        _hasNewPendingAssistantSinceViewed = false;
      });
    }
  }

  /// Detects a remote reassignment away from the facility this session
  /// is currently viewing - e.g. a facility Admin reassigning this
  /// assistant to a different facility via Manage Assistants, while
  /// this device is still actively signed in and looking at the old
  /// one. Firestore rules already correctly deny access to the old
  /// facility's data at that point, but without this check the already
  /// -loaded Provider state (products, clients, sales already fetched
  /// before the reassignment) would keep showing on screen, stale and
  /// silently inaccessible, until something else forced a refresh.
  Future<void> _checkStillAssignedToActiveFacility() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    if (!mounted) return;

    final activeFacilityId =
        Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId;
    if (activeFacilityId == null) return;

    try {
      final userDoc = await FirebaseFirestore.instance.collection(Collections.users).doc(user.uid).get();
      final facilityIds = (userDoc.data()?['facilityIds'] as List?)?.cast<String>() ?? [];
      if (!facilityIds.contains(activeFacilityId)) {
        await forceLogoutAndShowLogin(
          message: L10n.current.dashboard_reassigned,
        );
      }
    } catch (e) {
      debugPrint('Facility assignment check failed: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Coming back to the app is a natural, low-cost moment to check -
    // catches a revocation that happened while this device was
    // backgrounded, without waiting for the next periodic tick.
    if (state == AppLifecycleState.resumed) {
      SessionValidityService.checkAndHandleRevocation();
      _checkStillAssignedToActiveFacility();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionCheckTimer?.cancel();
    _urgentWatchSub?.cancel();
    _pendingWatchSub?.cancel();
    _periodTotalsSub?.cancel();
    _bellFeed?.dispose();
    super.dispose();
  }

  // Period-aware dashboard figures (Total Sales, Earnings, Profit,
  // Expenses, Completed Services) - fetched from precomputed daily
  // aggregates via DashboardSummaryService, not derived from whatever
  // happens to be loaded in each provider's paginated list.
  final DashboardSummaryService _dashboardSummaryService = DashboardSummaryService();
  DashboardPeriodTotals _periodTotals = DashboardPeriodTotals.empty;
  // Once true, a refresh keeps showing the last-known values instead of
  // blanking them out with a loading spinner - only the very first load
  // (when there's genuinely nothing to show yet) should look like loading.
  bool _hasLoadedDashboardOnce = false;
  bool _isPeriodLoading = false;
  String? _lastLoadedFacilityId;

  // The Recent Activity feed's stream, kept per facility and role. It used to
  // be built inline on every rebuild, handing the StreamBuilder a brand-new
  // stream each time.
  Stream<List<LogDoc>>? _recentActivityStream;
  String? _recentActivityKey;
  // The feed is built in one of two layout branches (side by side when wide,
  // stacked when narrow). This key moves the same feed, with its state and
  // subscription, from one to the other on a resize, instead of building a
  // new one (DASH-1).
  final _recentActivityFeedKey = GlobalKey();

  // What each role sees: recentActivityStream (dashboard_panels.dart).
  Stream<List<LogDoc>> _recentActivityStreamFor(String facilityId, bool isAdmin) {
    final key = '$facilityId|$isAdmin';
    final cached = _recentActivityStream;
    if (_recentActivityKey == key && cached != null) return cached;
    _recentActivityKey = key;
    return _recentActivityStream = recentActivityStream(FirebaseFirestore.instance, facilityId,
        isAdmin: isAdmin, uid: FirebaseAuth.instance.currentUser?.uid ?? '');
  }
  String? _lastLoadedFilter;
  StreamSubscription<DashboardPeriodTotals>? _periodTotalsSub;

  // The immediately-preceding equivalent period's totals, for the
  // dashboard's trend indicators - a one-time fetch, not a live stream,
  // since a completed past period doesn't need to keep updating the
  // way the current, still-in-progress one does.
  DashboardPeriodTotals _previousPeriodTotals = DashboardPeriodTotals.empty;
  bool _isPreviousPeriodLoading = false;

  // "Today at a Glance" strip - always today specifically, regardless
  // of whatever selectedFilter (Today/This Week/etc.) the main metric
  // cards above are currently showing.
  int? _glanceSaleCount;
  int? _glanceServiceCount;
  double? _glanceCollected;
  bool _isGlanceLoading = false;
  int _glanceRequestId = 0;

  // Sales & Revenue chart - its own period selector, independent of
  // the metric cards' selectedFilter above. Daily granularity only;
  // "This Year" isn't offered since 365 daily points wouldn't render
  // usefully on a line chart without separate monthly-bucket logic.
  String _chartPeriod = 'Last 7 days';
  List<double>? _chartSalesByDay;
  List<double>? _chartCollectionsByDay;
  List<double>? _chartServicesByDay;
  double? _chartPreviousTotal;
  double? _chartOtherIncomeTotal;
  bool _isChartLoading = false;
  int _chartRequestId = 0;

  // The point-in-time balances (product value, outstanding debt,
  // client count) from the equivalent point in the preceding period -
  // read from dailySnapshots, the once-daily record recordDailySnapshots
  // (functions/index.js) writes for exactly this purpose. Unlike the
  // flow totals above, these three have no "current vs previous range"
  // to sum over - they're a single recorded balance on a single day.
  Map<String, dynamic>? _previousSnapshot;
  bool _isPreviousSnapshotLoading = false;

  /// Turns the selected chip ('Today'/'This Week'/'This Month'/'This Year')
  /// into a concrete (start, end) date range.
  (DateTime, DateTime) _dateRangeForFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case 'Today':
        return (today, now);
      case 'This Week':
        // Monday as the start of the week.
        final startOfWeek = today.subtract(Duration(days: now.weekday - 1));
        return (startOfWeek, now);
      case 'This Month':
        return (DateTime(now.year, now.month, 1), now);
      case 'This Year':
        return (DateTime(now.year, 1, 1), now);
      default:
        return (today, now);
    }
  }

  /// The immediately-preceding equivalent period, for trend
  /// comparisons - the full prior period (yesterday, last week, last
  /// calendar month, last calendar year), not a time-of-day-prorated
  /// slice of it. The underlying daily aggregates this reads from are
  /// per-day, not per-hour, so there's nothing finer to prorate against
  /// anyway - this is also how most business dashboards handle "today
  /// vs yesterday": today's still-in-progress total against
  /// yesterday's complete one, not an artificially truncated
  /// yesterday.
  /// The label shown alongside each KPI's trend indicator - what it's
  /// actually being compared against, since a bare percentage on its
  /// own doesn't say what period it's relative to.
  String _comparisonLabelForFilter(String filter) {
    final l = context.l10n;
    switch (filter) {
      case 'Today':
        return l.dashboard_vsYesterday;
      case 'This Week':
        return l.dashboard_vsLastWeek;
      case 'This Month':
        return l.dashboard_vsLastMonth;
      case 'This Year':
        return l.dashboard_vsLastYear;
      default:
        return l.dashboard_vsYesterday;
    }
  }

  /// What a period choice is shown as. selectedFilter and _chartPeriod keep
  /// their English values ('Today', 'Last 7 days', ...), which the code above
  /// compares; only the label is localised.
  String _periodLabel(String filter) {
    final l = context.l10n;
    switch (filter) {
      case 'Today':
        return l.common_today;
      case 'This Week':
        return l.payments_thisWeek;
      case 'This Month':
        return l.payments_thisMonth;
      case 'This Year':
        return l.export_thisYear;
      case 'Last 7 days':
        return l.services_last7;
      case 'Last 30 days':
        return l.services_last30;
      default:
        return filter;
    }
  }

  (DateTime, DateTime) _previousPeriodRangeForFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case 'Today':
        final yesterday = today.subtract(AppRanges.day);
        return (yesterday, yesterday);
      case 'This Week':
        final startOfThisWeek = today.subtract(Duration(days: now.weekday - 1));
        final startOfLastWeek = startOfThisWeek.subtract(AppRanges.week);
        final endOfLastWeek = startOfThisWeek.subtract(AppRanges.day);
        return (startOfLastWeek, endOfLastWeek);
      case 'This Month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        // DateTime normalizes month: 0 to December of the previous
        // year on its own, so January correctly rolls back into last
        // December here without special-casing it.
        final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayOfLastMonth = firstOfThisMonth.subtract(AppRanges.day);
        return (firstOfLastMonth, lastDayOfLastMonth);
      case 'This Year':
        return (DateTime(now.year - 1, 1, 1), DateTime(now.year - 1, 12, 31));
      default:
        final yesterday = today.subtract(AppRanges.day);
        return (yesterday, yesterday);
    }
  }

  void _loadPeriodTotals(String facilityId) {
    if (!_hasLoadedDashboardOnce) setState(() => _isPeriodLoading = true);

    final (start, end) = _dateRangeForFilter(selectedFilter);

    // Cancel whatever was watching before - a stale subscription from
    // the previous facility/filter would otherwise keep emitting into
    // this same state alongside the new one.
    _periodTotalsSub?.cancel();
    _periodTotalsSub = _dashboardSummaryService
        .watchDashboardTotals(facilityId: facilityId, start: start, end: end)
        .listen((totals) {
      if (mounted) {
        setState(() {
          _periodTotals = totals;
          _isPeriodLoading = false;
        });
      }
    }, onError: (e) {
      debugPrint('Error watching dashboard period totals: $e');
      if (mounted) {
        setState(() => _isPeriodLoading = false);
      }
    });
  }

  int _previousPeriodRequestId = 0;

  void _loadPreviousPeriodTotals(String facilityId) {
    if (!_hasLoadedDashboardOnce) setState(() => _isPreviousPeriodLoading = true);

    final (start, end) = _previousPeriodRangeForFilter(selectedFilter);
    final requestId = ++_previousPeriodRequestId;

    _dashboardSummaryService
        .getDashboardTotals(facilityId: facilityId, start: start, end: end)
        .then((totals) {
      // Discard if a newer facility/filter selection has already
      // superseded this request - a Future (unlike the live stream
      // above) can't be cancelled outright, so this guards against a
      // slow, stale fetch overwriting a newer one's result.
      if (requestId != _previousPeriodRequestId) return;
      if (mounted) {
        setState(() {
          _previousPeriodTotals = totals;
          _isPreviousPeriodLoading = false;
        });
      }
    }).catchError((e) {
      debugPrint('Error fetching previous period totals: $e');
      if (requestId != _previousPeriodRequestId) return;
      if (mounted) {
        setState(() => _isPreviousPeriodLoading = false);
      }
    });
  }

  // Re-triggers every facility-dependent dashboard load, guarded
  // against a missing facility id. Called right after a sale or
  // service is successfully recorded, so Total Revenue and the chart
  // reflect it immediately rather than waiting for the person to
  // manually change a filter to force a reload.
  void _refreshDashboardData() {
    final facilityId = _lastLoadedFacilityId;
    if (facilityId == null) return;
    _hasLoadedDashboardOnce = true;
    _loadPeriodTotals(facilityId);
    _loadPreviousPeriodTotals(facilityId);
    _loadPreviousSnapshot(facilityId);
    _loadTodayGlance(facilityId);
    _loadChartData(facilityId);
  }

  void _loadTodayGlance(String facilityId) {
    if (!_hasLoadedDashboardOnce) setState(() => _isGlanceLoading = true);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestId = ++_glanceRequestId;

    Future.wait([
      SalesSummaryService().getRangeTotals(facilityId: facilityId, start: today, end: today),
      SalesSummaryService().getTotalCollected(facilityId: facilityId, start: today, end: today),
      _dashboardSummaryService.getDashboardTotals(facilityId: facilityId, start: today, end: today),
      SalesSummaryService().getTotalOtherIncome(facilityId: facilityId, start: today, end: today),
    ]).then((results) {
      // Discard if a newer facility selection has already superseded
      // this request - same reasoning as _loadPreviousPeriodTotals.
      if (requestId != _glanceRequestId) return;
      if (!mounted) return;

      final salesTotals = results[0] as Map<String, double>;
      final collected = results[1] as double;
      final dashboardTotals = results[2] as DashboardPeriodTotals;
      final otherIncome = results[3] as double;

      setState(() {
        _glanceSaleCount = (salesTotals['saleCount'] ?? 0).toInt();
        _glanceCollected = collected + otherIncome;
        _glanceServiceCount = dashboardTotals.completedServicesCount;
        _isGlanceLoading = false;
      });
    }).catchError((e) {
      debugPrint('Error loading today-at-a-glance totals: $e');
      if (requestId != _glanceRequestId) return;
      if (mounted) {
        setState(() => _isGlanceLoading = false);
      }
    });
  }

  (DateTime, DateTime, int) _chartDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final days = _chartPeriod == 'Last 30 days' ? 30 : 7;
    return (today.subtract(Duration(days: days - 1)), today, days);
  }

  void _loadChartData(String facilityId) {
    if (!_hasLoadedDashboardOnce) setState(() => _isChartLoading = true);

    final (start, end, days) = _chartDateRange();
    final requestId = ++_chartRequestId;
    final salesService = SalesSummaryService();

    final previousEnd = start.subtract(AppRanges.day);
    final previousStart = previousEnd.subtract(Duration(days: days - 1));

    Future.wait([
      salesService.getDailySummaries(facilityId: facilityId, start: start, end: end),
      salesService.getDailyCollections(facilityId: facilityId, start: start, end: end),
      salesService.getRangeTotals(facilityId: facilityId, start: previousStart, end: previousEnd),
      salesService.getDailyServiceSummaries(facilityId: facilityId, start: start, end: end),
      salesService.getTotalOtherIncome(facilityId: facilityId, start: start, end: end),
      salesService.getDailyServiceSummaries(facilityId: facilityId, start: previousStart, end: previousEnd),
      salesService.getTotalOtherIncome(facilityId: facilityId, start: previousStart, end: previousEnd),
    ]).then((results) {
      if (requestId != _chartRequestId) return;
      if (!mounted) return;

      final dailySales = results[0] as List<DailySalesSummary>;
      final dailyCollections = results[1] as List<DailyCollection>;
      final previousTotals = results[2] as Map<String, double>;
      final dailyServices = results[3] as List<DailyServiceSummary>;
      final otherIncomeTotal = results[4] as double;
      final previousDailyServices = results[5] as List<DailyServiceSummary>;
      final previousOtherIncomeTotal = results[6] as double;

      final salesByDate = {for (final s in dailySales) s.date: s.totalAmount};
      final collectedByDate = {for (final c in dailyCollections) c.date: c.totalCollected};
      final servicesByDate = {for (final s in dailyServices) s.date: s.totalAmount};

      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      // Every day in the range gets a point, 0 if nothing happened
      // that day - otherwise a quiet day would just be missing from
      // the chart entirely rather than showing as a dip to zero.
      final salesByDay = <double>[];
      final collectionsByDay = <double>[];
      final servicesByDay = <double>[];
      for (int i = 0; i < days; i++) {
        final day = fmt(start.add(Duration(days: i)));
        salesByDay.add(salesByDate[day] ?? 0.0);
        collectionsByDay.add(collectedByDate[day] ?? 0.0);
        servicesByDay.add(servicesByDate[day] ?? 0.0);
      }

      final previousServicesTotal = previousDailyServices.fold<double>(0.0, (total, s) => total + s.totalAmount);
      final previousFullTotal =
          (previousTotals['totalAmount'] ?? 0.0) + previousServicesTotal + previousOtherIncomeTotal;

      setState(() {
        _chartSalesByDay = salesByDay;
        _chartCollectionsByDay = collectionsByDay;
        _chartServicesByDay = servicesByDay;
        _chartPreviousTotal = previousFullTotal;
        _chartOtherIncomeTotal = otherIncomeTotal;
        _isChartLoading = false;
      });
    }).catchError((e) {
      debugPrint('Error loading chart data: $e');
      if (requestId != _chartRequestId) return;
      if (mounted) {
        setState(() => _isChartLoading = false);
      }
    });
  }

  int _previousSnapshotRequestId = 0;

  void _loadPreviousSnapshot(String facilityId) {
    if (!_hasLoadedDashboardOnce) setState(() => _isPreviousSnapshotLoading = true);

    // The previous period's own end date - the most recent point
    // within that period, matching "what was the balance at the
    // equivalent point last period" (e.g. "This Month" compares
    // against the balance on the same day-of-month last month, not
    // the 1st of last month).
    final (_, end) = _previousPeriodRangeForFilter(selectedFilter);
    final dateKey =
        '${end.year.toString().padLeft(4, '0')}-${end.month.toString().padLeft(2, '0')}-${end.day.toString().padLeft(2, '0')}';
    final requestId = ++_previousSnapshotRequestId;

    FirebaseFirestore.instance
        .collection(Collections.facilities)
        .doc(facilityId)
        .collection(Collections.dailySnapshots)
        .doc(dateKey)
        .get()
        .then((doc) {
      if (requestId != _previousSnapshotRequestId) return;
      if (mounted) {
        setState(() {
          _previousSnapshot = doc.data();
          _isPreviousSnapshotLoading = false;
        });
      }
    }).catchError((e) {
      debugPrint('Error fetching previous daily snapshot: $e');
      if (requestId != _previousSnapshotRequestId) return;
      if (mounted) {
        setState(() {
          _previousSnapshot = null;
          _isPreviousSnapshotLoading = false;
        });
      }
    });
  }

  String greetingTime() {
    final hour = DateTime.now().hour;
    if (hour < 12) return context.l10n.dashboard_goodMorning;
    if (hour < 17) return context.l10n.dashboard_goodAfternoon;
    return context.l10n.dashboard_goodEvening;
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // PICK & SAVE USER PROFILE
  Future<void> pickProfileImage() async {
    if (user == null) return;

    final pickedFile = await _picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: AppLimits.avatarImageMaxSide,
      maxHeight: AppLimits.avatarImageMaxSide,
      imageQuality: AppLimits.pickedImageQuality,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!UploadSizeCheck.allow(bytes)) return;
    setState(() => _profileBytes = bytes);

    try {
      final storageRef = FirebaseStorage.instance.ref().child('user_avatars/${user!.uid}.png');
      await storageRef.putData(bytes, UploadContentTypes.png);
      final downloadUrl = await storageRef.getDownloadURL();
      await userDoc.update({'avatarUrl': downloadUrl});

      AppFeedback.success(L10n.current.dashboard_avatarUpdated);
    } catch (e, st) {
      AppFeedback.error(L10n.current.dashboard_avatarSaveFailed, error: e, stackTrace: st);
    }
  }

  void showConfirmationDialog({
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title, style: TextStyle(color: context.colors.primary)),
        content: Text(content),
        actions: [
          TextButton(
            child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.accent),
            child: Text(context.l10n.common_confirm),
            onPressed: () {
              Navigator.pop(context);
              onConfirm();
            },
          ),
        ],
      ),
    );
  }

  void _showChangePasswordDialog(String email) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(context.l10n.dashboard_resetPasswordTitle),
        content: Text(context.l10n.dashboard_resetPasswordPrompt(email)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(context.l10n.common_cancel),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: context.colors.primary),
            onPressed: () async {
              // Captured before the await: the dialog must close whether the
              // email was sent or not.
              final navigator = Navigator.of(context);
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                navigator.pop();
                AppFeedback.success(L10n.current.dashboard_resetLinkSent(email));
              } catch (e, st) {
                navigator.pop();
                AppFeedback.error(L10n.current.dashboard_resetLinkFailed, error: e, stackTrace: st);
              }
            },
            child: Text(context.l10n.dashboard_sendLink, style: TextStyle(color: context.colors.background)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final facilityProvider = Provider.of<FacilityProvider>(context);
    final selectedFacility = facilityProvider.selectedFacility;

    // If facility is not yet loaded, show loading indicator
    if (selectedFacility == null) {
    // Facility is required; redirect back to login
    Future.microtask(() {
      if (!context.mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    });
    return const SizedBox.shrink(); // Return empty widget temporarily
   }


    // Facility is loaded, we can safely access its fields
    final facilityName = selectedFacility['name'] ?? context.l10n.common_facility;
    final currentFacilityId = selectedFacility['id'];

    // Kick off a period-totals fetch whenever the facility or the
    // selected filter chip changes (guarded so it doesn't refire on every
    // unrelated rebuild).
    if (currentFacilityId != null &&
        (_lastLoadedFacilityId != currentFacilityId || _lastLoadedFilter != selectedFilter)) {
      // Same facility, just a different filter chip - the numbers on
      // screen are still valid to keep showing while the new range
      // loads in. A genuine facility switch resets this, so its
      // initial load still shows loading rather than the previous
      // facility's now-irrelevant numbers.
      _hasLoadedDashboardOnce = _lastLoadedFacilityId == currentFacilityId;
      _lastLoadedFacilityId = currentFacilityId;
      _lastLoadedFilter = selectedFilter;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _loadPeriodTotals(currentFacilityId);
        _loadPreviousPeriodTotals(currentFacilityId);
        _loadPreviousSnapshot(currentFacilityId);
        _loadTodayGlance(currentFacilityId);
        _loadChartData(currentFacilityId);
      });
    }

    // Providers
    final productProvider = Provider.of<ProductProvider>(context);
    final clientProvider = Provider.of<ClientProvider>(context);
    final debtProvider = Provider.of<DebtProvider>(context);

    // Distinct debtors with an outstanding balance - same grouping
    // logic as the Debtors screen's own "Total Debtors" count.
    final Map<String, double> owedByClient = {};
    for (final debt in debtProvider.debts) {
      owedByClient[debt.clientId] = (owedByClient[debt.clientId] ?? 0) + debt.amountOwed;
    }
    final glanceDebtorCount = owedByClient.values.where((v) => v > 0).length;


    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLargeScreen = constraints.maxWidth >= AppBreakpoints.expanded;

        return Scaffold(
          backgroundColor: context.colors.background,
          appBar: isLargeScreen ? null : AppBar(
            backgroundColor: context.colors.surface,
            elevation: AppElevation.e1,
            centerTitle: false,
            iconTheme: IconThemeData(color: context.colors.textPrimary),
            leading: isLargeScreen
                ? IconButton(
                    icon: Icon(_isDrawerCollapsed ? Icons.menu_open : Icons.menu, color: context.colors.textPrimary, size: AppIconSize.i22),
                    tooltip: _isDrawerCollapsed ? context.l10n.dashboard_expandMenu : context.l10n.dashboard_collapseMenu,
                    onPressed: _toggleDrawerCollapsed,
                  )
                : null,
            title: null,
            actions: [
              // Visual only for now - there's no global search feature
              // built yet, so this doesn't actually search anything.
              if (isLargeScreen)
                Container(
                  width: 260,
                  height: 38,
                  margin: const EdgeInsets.only(right: AppSpacing.s12),
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: AppIconSize.i18, color: context.colors.textHint),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: Text(context.l10n.dashboard_searchAnything,
                            style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textHint)),
                      ),
                      Text(context.l10n.dashboard_searchShortcut, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textDisabled)),
                    ],
                  ),
                ),
              _buildAlertsBell(context),
              // Reads whatever Platform Admin has set under Branding >
              // Contact Details, falling back to a generic message if
              // nothing's configured yet.
              IconButton(
                icon: Icon(Icons.help_outline, color: context.colors.textPrimary, size: AppIconSize.i22),
                tooltip: context.l10n.dashboard_help,
                onPressed: () => _showHelpDialog(context),
              ),
              const SizedBox(width: AppSpacing.s4),
              _buildProfileButton(),
            ],
          ),
          drawer: isLargeScreen ? null : Drawer(child: _buildDrawerContent()),
          endDrawer: Drawer(child: _buildEndDrawerContent()),
          body: Column(
            children: [
              Container(height: 1.2, width: double.infinity, color: context.colors.borderStrong),
              Expanded(
                child: Stack(
                  children: [
                    RepaintBoundary(
                      child: Row(
                      children: [
                        if (isLargeScreen) _buildDrawerContent(),
                        Expanded(
                          child: Column(
                            children: [
                              if (isLargeScreen) _buildTopBar(context),
                              Expanded(
                                child: Container(
                                  color: context.colors.background,
                                  child: Padding(
                                  padding: const EdgeInsets.all(AppSpacing.s16),
                                  child: SingleChildScrollView(
                                    child: Column(
                                    children: [
                                      StreamBuilder<DocumentSnapshot>(
                                  stream: userDoc.snapshots(),
                                  builder: (context, snapshot) {
                                    final rawData = snapshot.data?.data();
                                    final Map<String, dynamic> data = (rawData != null && rawData is Map)
                                        ? Map<String, dynamic>.from(rawData)
                                        : {};
                                    final fullName = data['fullName'] ?? '';

                                    final greetingColumn = Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(context.l10n.dashboard_greeting(greetingTime(), fullName),
                                            style: TextStyle(fontSize: AppFontSize.f20, fontWeight: AppFontWeight.bold, color: context.colors.textPrimary)),
                                        const SizedBox(height: AppSpacing.s2),
                                        Text(context.l10n.dashboard_howFacilityIsDoing(facilityName),
                                            style: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textMuted)),
                                      ],
                                    );

                                    final dateTimeRow = StreamBuilder(
                                      stream: Stream.periodic(AppTimeouts.clockTick),
                                      builder: (context, _) {
                                        final now = DateTime.now();
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PopupMenuButton<String>(
                                              tooltip: context.l10n.dashboard_changePeriod,
                                              onSelected: (val) => setState(() => selectedFilter = val),
                                              itemBuilder: (context) => ['Today', 'This Week', 'This Month', 'This Year']
                                                  .map((f) => PopupMenuItem(value: f, child: Text(_periodLabel(f))))
                                                  .toList(),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.calendar_today_outlined, size: AppIconSize.i14, color: context.colors.textHint),
                                                  const SizedBox(width: AppSpacing.s6),
                                                  Text(
                                                    selectedFilter == 'Today'
                                                        ? AppDateFormat.dateWeekdayShort.format(now)
                                                        : _periodLabel(selectedFilter),
                                                    style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted),
                                                  ),
                                                  const SizedBox(width: AppSpacing.s2),
                                                  Icon(Icons.arrow_drop_down, size: AppIconSize.i16, color: context.colors.textHint),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: AppSpacing.s14),
                                            Icon(Icons.access_time, size: AppIconSize.i14, color: context.colors.textHint),
                                            const SizedBox(width: AppSpacing.s6),
                                            Text(AppDateFormat.time12.format(now),
                                                style: TextStyle(fontSize: AppFontSize.f12_5, color: context.colors.textMuted)),
                                          ],
                                        );
                                      },
                                    );

                                    if (isLargeScreen) {
                                      return Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [greetingColumn, dateTimeRow],
                                      );
                                    }
                                    return Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        greetingColumn,
                                        const SizedBox(height: AppSpacing.s8),
                                        dateTimeRow,
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: AppSpacing.s16),
                            LayoutBuilder(
                              builder: (context, gridConstraints) {
                                final gridWidth = gridConstraints.maxWidth;
                                // More columns on wide screens - each
                                // card gets a fixed height (mainAxisExtent
                                // below) regardless of width, since
                                // SummaryCard's content needs a
                                // consistent minimum height to avoid
                                // overflowing.
                                final crossAxisCount = gridWidth > 1200
                                    ? 4
                                    : gridWidth > 700
                                        ? 3
                                        : 2;
                                final cards = [
                                      SummaryCard(
                                        title: context.l10n.dashboard_totalProductValue,
                                        value: Money.format(productProvider.totalProductValue),
                                        icon: Icons.inventory,
                                        color: context.colors.primary,
                                        shadow: true,
                                        subtitle: context.l10n.dashboard_asOfNow,
                                        trend: KpiTrend(
                                          currentValue: productProvider.totalProductValue,
                                          previousValue:
                                              (_previousSnapshot?['totalProductValue'] as num?)?.toDouble() ?? 0,
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => Money.format(v),
                                          isLoading: _isPreviousSnapshotLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: context.l10n.dashboard_totalSales(_periodLabel(selectedFilter)),
                                        value: Money.format(_periodTotals.totalSales),
                                        icon: Icons.shopping_cart,
                                        color: context.colors.accent,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        trend: KpiTrend(
                                          currentValue: _periodTotals.totalSales,
                                          previousValue: _previousPeriodTotals.totalSales,
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => Money.format(v),
                                          isLoading: _isPreviousPeriodLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: context.l10n.dashboard_totalCollected(_periodLabel(selectedFilter)),
                                        value: Money.format(_periodTotals.totalCollected),
                                        icon: Icons.attach_money,
                                        color: context.colors.primary,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        trend: KpiTrend(
                                          currentValue: _periodTotals.totalCollected,
                                          previousValue: _previousPeriodTotals.totalCollected,
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => Money.format(v),
                                          isLoading: _isPreviousPeriodLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: context.l10n.dashboard_netProfit(_periodLabel(selectedFilter)),
                                        value: Provider.of<UserRoleProvider>(context).isAdmin
                                            ? Money.format(_periodTotals.netProfit)
                                            : '*****',
                                        icon: Icons.trending_up,
                                        color: context.colors.primary,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        trendOnTitleRow: true,
                                        // Hidden entirely for non-admins, same
                                        // as the value itself - a trend arrow
                                        // would still leak directional profit
                                        // information even with the figure
                                        // masked.
                                        trend: Provider.of<UserRoleProvider>(context).isAdmin
                                            ? KpiTrend(
                                                currentValue: _periodTotals.netProfit,
                                                previousValue: _previousPeriodTotals.netProfit,
                                                higherIsBetter: true,
                                                comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                                formatChange: (v) => Money.format(v),
                                                isLoading: _isPreviousPeriodLoading,
                                              )
                                            : null,
                                        // The realized/pending breakdown also
                                        // reveals profit information, so it's
                                        // masked the same way as the headline
                                        // figure and trend above.
                                        footer: Provider.of<UserRoleProvider>(context).isAdmin
                                            ? _profitBreakdownFooter(
                                                _periodTotals.totalRealizedProfit,
                                                _periodTotals.totalUnrealizedProfit,
                                              )
                                            : null,
                                      ),
                                      SummaryCard(
                                        title: context.l10n.dashboard_totalExpenses(_periodLabel(selectedFilter)),
                                        value: Money.format(_periodTotals.totalExpenses),
                                        icon: Icons.trending_down,
                                        color: context.colors.danger,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        trend: KpiTrend(
                                          currentValue: _periodTotals.totalExpenses,
                                          previousValue: _previousPeriodTotals.totalExpenses,
                                          // Rising expenses is the bad
                                          // outcome here, even though the
                                          // number itself went up.
                                          higherIsBetter: false,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => Money.format(v),
                                          isLoading: _isPreviousPeriodLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: context.l10n.dashboard_outstandingPayment,
                                        value: Money.format(debtProvider.totalOutstanding()),
                                        icon: Icons.account_balance_wallet,
                                        color: context.colors.accent,
                                        shadow: true,
                                        subtitle: context.l10n.dashboard_asOfNow,
                                        trend: KpiTrend(
                                          currentValue: debtProvider.totalOutstanding(),
                                          previousValue:
                                              (_previousSnapshot?['totalOutstanding'] as num?)?.toDouble() ?? 0,
                                          // Rising debt owed is the bad
                                          // outcome here too.
                                          higherIsBetter: false,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => Money.format(v),
                                          isLoading: _isPreviousSnapshotLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: context.l10n.clients_total,
                                        value: '${clientProvider.clients.length}',
                                        icon: Icons.people,
                                        color: context.colors.accent,
                                        shadow: true,
                                        subtitle: context.l10n.dashboard_asOfNow,
                                        trend: KpiTrend(
                                          currentValue: clientProvider.clients.length.toDouble(),
                                          previousValue:
                                              (_previousSnapshot?['totalClients'] as num?)?.toDouble() ?? 0,
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => v.round().toString(),
                                          isLoading: _isPreviousSnapshotLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: context.l10n.dashboard_completedServices(_periodLabel(selectedFilter)),
                                        value: '${_periodTotals.completedServicesCount}',
                                        icon: Icons.design_services,
                                        color: context.colors.chart1,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        trend: KpiTrend(
                                          currentValue: _periodTotals.completedServicesCount.toDouble(),
                                          previousValue: _previousPeriodTotals.completedServicesCount.toDouble(),
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => v.round().toString(),
                                          isLoading: _isPreviousPeriodLoading,
                                        ),
                                      ),
                                    ];

                                return GridView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    mainAxisExtent: 120,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: cards.length,
                                  itemBuilder: (context, index) => cards[index],
                                );
                              },
                            ),
                            const SizedBox(height: AppSpacing.s16),
                            DashboardLowerPanels(
                              glance: TodayGlanceStrip(
                                saleCount: _glanceSaleCount,
                                serviceCount: _glanceServiceCount,
                                collected: _glanceCollected,
                                isLoading: _isGlanceLoading,
                                debtorCount: glanceDebtorCount,
                              ),
                              wide: isLargeScreen,
                              chart: _buildSalesRevenueChart(),
                              feed: _buildRecentActivityFeed(),
                              quickActions: _buildQuickActionCards(context),
                            ),
                          ],
                        ),
                                ),
                              ),
                            ),
                          ),
                            ],
                            ),
                        ),
                      ],
                    ),
                    ),
                Positioned(
                      top: 56,
                      left: 0,
                      right: 0,
                      child: Center(child: _buildSubscriptionBanner(context)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Shown at the very top of the dashboard whenever the current
  // account's email hasn't been verified yet - a gentle, persistent
  // nudge rather than a hard block, since forcing verification before
  // allowing any use of the app risks locking out a busy shop owner
  // over spotty email delivery, when the real risk it protects against
  // (a typo'd email breaking password recovery later) is adequately
  // covered by a visible reminder instead.
  // Shown at the very top of the dashboard, every time it opens - trial
  // (no subscription set up yet) shows nothing, since that's the normal
  // unrestricted state, not something to warn about.
  // Always present in the tree (never conditionally omitted) so the
  // AnimatedAlign/AnimatedOpacity below can actually animate between
  // shown and hidden - returning a completely different widget
  // (SizedBox.shrink() vs. the full banner) would just snap instantly,
  // since Flutter has nothing to animate between two unrelated trees.
  // A compact, cream pill rather than a full-width strip - the warning
  // comes through the icon color and text, not a loud background fill,
  // so it sits comfortably alongside the app's otherwise soft, muted
  // palette instead of being the one loud element on the screen. Lives
  // inline in the Today/This Week/.../Insights row now, vertically
  // centered with those chips rather than occupying its own separate
  // strip across the screen.
  Widget _buildSubscriptionBanner(BuildContext context) {
    final sub = Provider.of<SubscriptionProvider>(context);

    final needsAttention = sub.status == SubscriptionStatus.grace ||
        sub.status == SubscriptionStatus.locked ||
        ((sub.status == SubscriptionStatus.trial || sub.status == SubscriptionStatus.active) &&
            sub.daysRemaining != null &&
            sub.daysRemaining! <= 7);

    // Calm, informational - shown for the rest of the trial once the
    // urgent <=7-day window above doesn't apply yet, rather than
    // showing nothing at all until it's nearly over.
    final isInTrialInfo = sub.isInCalmTrial; // one shared definition - see SubscriptionProvider

    final isSnoozed = _subscriptionSnoozedUntil != null &&
        DateTime.now().isBefore(_subscriptionSnoozedUntil!);
    final shouldShow = (needsAttention || isInTrialInfo) && !isSnoozed && _subscriptionPillDelayPassed;

    final isLocked = sub.status == SubscriptionStatus.locked;
    final isGrace = sub.status == SubscriptionStatus.grace;
    final isTrial = sub.status == SubscriptionStatus.trial;
    // The accent - carried by the icon, the text, and a thin border -
    // rather than a full background fill. Same deepened, burnt-amber
    // reasoning as before: the brand's own amber (accent) is too close to
    // yellow to read cleanly as an accent on a cream background.
    final accent = isLocked ? context.colors.dangerAccent : (isInTrialInfo ? context.colors.info : context.colors.warningBannerText);

    // Full sentence now that this sits in its own row above the filter
    // chips, rather than the shortened version needed when it was
    // squeezed inline next to Insights.
    final l = context.l10n;
    String message;
    if (isLocked) {
      message = isTrial ? l.subscription_trialEndedReadOnly : l.subscription_expiredReadOnly;
    } else if (isGrace) {
      message = isTrial ? l.subscription_trialEndedGrace : l.subscription_expiredGrace;
    } else if (isInTrialInfo) {
      // A legacy facility with no trial/subscription date recorded at
      // all reaches this branch with daysRemaining null - shown as an
      // open-ended trial rather than ever interpolating "null" into
      // the sentence.
      message = sub.daysRemaining != null
          ? l.subscription_freeTrialDaysLeft(sub.daysRemaining!)
          : l.subscription_onFreeTrial;
    } else if (isTrial) {
      message = sub.daysRemaining != null
          ? l.subscription_trialExpiresIn(sub.daysRemaining!)
          : l.subscription_trialActive;
    } else {
      message = sub.daysRemaining != null
          ? l.subscription_expiresIn(sub.daysRemaining!)
          : l.subscription_active;
    }

    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return AnimatedSwitcher(
      duration: _bannerSwitch,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: CurvedAnimation(parent: animation, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
        child: ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: Curves.easeOutBack),
          child: child,
        ),
      ),
      child: !shouldShow
          ? const SizedBox.shrink(key: ValueKey('sub-banner-hidden'))
          : Container(
              key: const ValueKey('sub-banner-shown'),
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s14, vertical: AppSpacing.s8),
              decoration: BoxDecoration(
                color: context.colors.warningBannerFill.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(AppRadius.r24),
                border: Border.all(color: accent.withValues(alpha: AppAlpha.a40)),
                boxShadow: [
                  BoxShadow(color: context.colors.shadow.withValues(alpha: AppAlpha.a05), blurRadius: 6, offset: const Offset(0, 2)),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    isLocked
                        ? Icons.lock_outline
                        : (isInTrialInfo ? Icons.workspace_premium_outlined : Icons.warning_amber_rounded),
                    color: accent,
                    size: AppIconSize.i16,
                  ),
                  const SizedBox(width: AppSpacing.s6),
                  Text(
                    message,
                    style: TextStyle(color: context.colors.textPrimary, fontSize: AppFontSize.f12_5, fontWeight: AppFontWeight.semibold),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: AppSpacing.s16),
                    GestureDetector(
                      onTap: () => showSubscriptionScreen(context),
                      child: Text(
                        isInTrialInfo ? l.subscription_viewPlans : l.subscription_renew,
                        style: TextStyle(
                          color: accent,
                          fontSize: AppFontSize.f12_5,
                          fontWeight: AppFontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: AppSpacing.s8),
                    Text(l.subscription_askYourAdmin,
                        style: TextStyle(color: context.colors.textMuted, fontSize: AppFontSize.f11_5, fontStyle: FontStyle.italic)),
                  ],
                  // Snoozes rather than dismisses permanently - see the
                  // note on _subscriptionSnoozeDuration above for why.
                  const SizedBox(width: AppSpacing.s4),
                  InkWell(
                    borderRadius: BorderRadius.circular(AppRadius.r12),
                    onTap: _snoozeSubscriptionBanner,
                    child: Padding(
                      padding: const EdgeInsets.all(AppSpacing.s4),
                      child: Icon(Icons.close, size: AppIconSize.i16, color: context.colors.textHint),
                    ),
                  ),
                ],
              ),
            ),
    );
  }


  // Compact bell icon with a red dot when there's a low-stock or
  // expiring-item alert - replaces the old full-width banner. Tapping it
  // goes straight to the same screen Settings > Notifications leads to.
  /// Anchors a compact notifications panel near the bell's actual
  /// measured position - it sits in different places depending on
  /// screen width (AppBar leading on wide screens, actions on
  /// narrow), so this can't assume a fixed corner the way a generic
  /// modal could. Transparent barrier rather than a dimmed one - this
  /// should read as a dropdown anchored to the bell, not a modal
  /// taking over the screen.
  Future<void> _showNotificationsDropdown(BuildContext context) async {
    final renderBox = _bellKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;
    final bellPosition = renderBox.localToGlobal(Offset.zero);
    final bellSize = renderBox.size;
    final screenSize = MediaQuery.of(context).size;

    const panelWidth = 400.0;
    // Keeps the panel on-screen if the bell sits close to the right
    // edge - anchors to the bell's left edge by default, but shifts
    // left just enough to stay within the viewport otherwise.
    final left = (bellPosition.dx + panelWidth > screenSize.width - 16)
        ? screenSize.width - panelWidth - 16
        : bellPosition.dx;

    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: context.l10n.common_notifications,
      barrierColor: Colors.transparent,
      transitionDuration: AppMotion.fast,
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: bellPosition.dy + bellSize.height + 8,
              left: left,
              child: Material(
                elevation: AppElevation.e8,
                borderRadius: BorderRadius.circular(AppRadius.r12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: panelWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenSize.height * 0.75),
                    child: const NotificationsScreen(isDropdown: true),
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.95, end: 1.0).animate(curved),
            alignment: Alignment.topLeft,
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildRecentActivityFeed() {
    final facilityId = _lastLoadedFacilityId;
    return RecentActivityFeed(
      key: _recentActivityFeedKey,
      stream: facilityId == null ? null : _recentActivityStreamFor(facilityId, Provider.of<UserRoleProvider>(context).isAdmin),
      // A new stream (the cached one may have failed).
      onRetry: () => setState(() => _recentActivityStream = null),
    );
  }

  Widget _buildSalesRevenueChart() {
    final (start, _, days) = _chartDateRange();
    return SalesRevenueChart(
      salesByDay: _chartSalesByDay,
      collectionsByDay: _chartCollectionsByDay,
      servicesByDay: _chartServicesByDay,
      otherIncomeTotal: _chartOtherIncomeTotal,
      previousTotal: _chartPreviousTotal,
      isLoading: _isChartLoading,
      period: _chartPeriod,
      periodLabel: _periodLabel,
      onPeriodChanged: (val) {
        setState(() => _chartPeriod = val);
        final facilityId = _lastLoadedFacilityId;
        if (facilityId != null) _loadChartData(facilityId);
      },
      start: start,
      days: days,
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.only(left: AppSpacing.s16, right: AppSpacing.s16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        border: Border(bottom: BorderSide(color: context.colors.textHint.withValues(alpha: AppAlpha.a20))),
      ),
      child: Row(
        children: [
          // Hidden in Layout Fixed Mode: the sidebar is held open, so a button
          // for collapsing it would only do nothing.
          if (!Provider.of<UiSettingsProvider>(context).layoutFixed)
            IconButton(
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              icon: Icon(_isDrawerCollapsed ? Icons.menu_open : Icons.menu, color: context.colors.textPrimary, size: AppIconSize.i22),
              tooltip: _isDrawerCollapsed ? context.l10n.dashboard_expandMenu : context.l10n.dashboard_collapseMenu,
              onPressed: _toggleDrawerCollapsed,
            ),
          const Spacer(),
          Container(
            width: 260,
            margin: const EdgeInsets.only(right: AppSpacing.s12),
            child: Autocomplete<_DashboardSearchResult>(
              displayStringForOption: (r) => r.title,
              optionsBuilder: (textEditingValue) {
                final query = textEditingValue.text.trim().toLowerCase();
                if (query.isEmpty) return const Iterable<_DashboardSearchResult>.empty();

                final productProvider = Provider.of<ProductProvider>(context, listen: false);
                final clientProvider = Provider.of<ClientProvider>(context, listen: false);
                final results = <_DashboardSearchResult>[];

                for (final p in productProvider.products) {
                  if (p.name.toLowerCase().contains(query)) {
                    results.add(_DashboardSearchResult(
                      title: p.name,
                      subtitle: context.l10n.reports_colProduct,
                      icon: Icons.inventory_2_outlined,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ProductsScreen(initialSearchQuery: p.name)),
                      ),
                    ));
                  }
                }
                for (final c in clientProvider.clients) {
                  if (c.name.toLowerCase().contains(query) || c.phone.contains(query)) {
                    results.add(_DashboardSearchResult(
                      title: c.name,
                      subtitle: context.l10n.dashboard_searchClient(c.phone),
                      icon: Icons.person_outline,
                      onTap: () =>
                          Navigator.push(context, MaterialPageRoute(builder: (_) => const ClientsScreen())),
                    ));
                  }
                }
                return results.take(8);
              },
              onSelected: (r) => r.onTap(),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                return Container(
                  height: 38,
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s12),
                  decoration: BoxDecoration(
                    color: context.colors.background,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    border: Border.all(color: context.colors.textHint.withValues(alpha: AppAlpha.a30)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: AppIconSize.i18, color: context.colors.textHint),
                      const SizedBox(width: AppSpacing.s8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(fontSize: AppFontSize.f13),
                          decoration: InputDecoration.collapsed(
                            hintText: context.l10n.dashboard_searchProductsOrClients,
                            hintStyle: TextStyle(fontSize: AppFontSize.f13, color: context.colors.textHint),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                final list = options.toList();
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: AppElevation.e2,
                    borderRadius: BorderRadius.circular(AppRadius.r8),
                    child: SizedBox(
                      width: 300,
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, index) {
                          final r = list[index];
                          return ListTile(
                            dense: true,
                            leading: Icon(r.icon, size: AppIconSize.i18, color: context.colors.primary),
                            title: Text(r.title, style: const TextStyle(fontSize: AppFontSize.f13)),
                            subtitle: Text(r.subtitle, style: const TextStyle(fontSize: AppFontSize.f11)),
                            onTap: () => onSelected(r),
                          );
                        },
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          _buildAlertsBell(context),
          // Reads whatever Platform Admin has set under Branding >
          // Contact Details, falling back to a generic message if
          // nothing's configured yet.
          IconButton(
            icon: Icon(Icons.help_outline, color: context.colors.textPrimary, size: AppIconSize.i22),
            tooltip: context.l10n.dashboard_help,
            onPressed: () => _showHelpDialog(context),
          ),
          const SizedBox(width: AppSpacing.s4),
          _buildProfileButton(),
        ],
      ),
    );
  }

  // The small, compact breakdown shown under Net Profit's headline
  // figure - Realized is the portion actually backed by cash already
  // collected (paid sales/services, or a debt repayment); Pending is
  // the portion still tied up in an unpaid credit balance.
  Widget _profitBreakdownFooter(double realized, double pending) {
    return SizedBox(
      width: double.infinity,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.s22),
                    child: _profitBreakdownDot(context.l10n.dashboard_profitEarned, realized, context.colors.success),
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(left: AppSpacing.s16),
                    child: _profitBreakdownDot(context.l10n.dashboard_profitPending, pending, context.colors.accent),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.s2, left: AppSpacing.s4),
            child: Tooltip(
              message: context.l10n.dashboard_profitHelp,
              child: Icon(Icons.info_outline, size: AppIconSize.i16, color: context.colors.textDisabled),
            ),
          ),
        ],
      ),
    );
  }

  // Compact form for large amounts in the Earned/Pending breakdown,
  // which has far less room than the headline Net Profit figure above
  // it - "Tsh 10.888M" instead of "Tsh 10,000,888". Only kicks in at a
  // million or more; anything smaller uses the normal formatter, which
  // already fits comfortably in the space available.
  String _formatCompactAmount(double value) => Money.compactMillions(value);

  Widget _profitBreakdownDot(String label, double value, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: AppSpacing.s4),
          child: Container(width: 6, height: 6, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        ),
        const SizedBox(width: AppSpacing.s4),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: TextStyle(fontSize: AppFontSize.f10_5, color: context.colors.textMuted), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_formatCompactAmount(value),
                style: TextStyle(fontSize: AppFontSize.f12, fontWeight: AppFontWeight.semibold, color: context.colors.textPrimary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ],
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= AppBreakpoints.expanded;

    final cards = [
      _quickActionCard(
        icon: Icons.add_shopping_cart,
        title: context.l10n.sales_recordSale,
        subtitle: context.l10n.dashboard_createNewSale,
        backgroundColor: context.colors.brandSurface,
        accentColor: context.colors.primary,
        isDark: true,
        onTap: () async {
          await navigateOrShowLockedDialog(
            context,
            const AddSaleScreen(),
            onNavigate: () => showAddSaleScreen(context),
          );
          _refreshDashboardData();
        },
      ),
      _quickActionCard(
        icon: Icons.design_services,
        title: context.l10n.services_recordVisit,
        subtitle: context.l10n.dashboard_addServiceRecord,
        backgroundColor: context.colors.quickActionTintPrimary,
        accentColor: context.colors.primary,
        isDark: false,
        onTap: () async {
          await navigateOrShowLockedDialog(
            context,
            const AddEditServiceScreen(),
            onNavigate: () => showAddEditServiceScreen(context),
          );
          _refreshDashboardData();
        },
      ),
      // Creating a product is admin-only (owner decision, E4d-2).
      if (Provider.of<UserRoleProvider>(context).isAdmin)
      _quickActionCard(
        icon: Icons.add_box,
        title: context.l10n.products_addProduct,
        subtitle: context.l10n.dashboard_addProductToStore,
        backgroundColor: context.colors.quickActionTintAccent,
        accentColor: context.colors.accent,
        isDark: false,
        onTap: () => showAddEditProductScreen(context),
      ),
    ];

    if (isLargeScreen) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: AppSpacing.s12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: AppSpacing.s12),
          cards[i],
        ],
      ],
    );
  }

  Widget _quickActionCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color backgroundColor,
    required Color accentColor,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    final textColor = isDark ? context.colors.onBrandSurface : context.colors.textPrimary;
    final subtitleColor = isDark ? context.colors.onBrandSurface.withValues(alpha: AppAlpha.a85) : context.colors.textSoft;
    final iconCircleColor = isDark ? context.colors.onBrandSurface.withValues(alpha: AppAlpha.a20) : accentColor.withValues(alpha: AppAlpha.a15);
    final iconColor = isDark ? context.colors.onBrandSurface : accentColor;
    final chevronColor = isDark ? context.colors.onBrandSurface : accentColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadius.r12),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.s16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(AppRadius.r12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconCircleColor,
                borderRadius: BorderRadius.circular(AppRadius.r10),
              ),
              child: Icon(icon, color: iconColor, size: AppIconSize.i20),
            ),
            const SizedBox(width: AppSpacing.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontWeight: AppFontWeight.bold, fontSize: AppFontSize.f14)),
                  Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: AppFontSize.f11_5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: chevronColor, size: AppIconSize.i20),
          ],
        ),
      ),
    );
  }

  // Reads whatever Platform Admin has filled in under Branding >
  // Contact Details - each field is optional, so this only shows rows
  // for what's actually set, and falls back to the original generic
  // message if none of the four have been configured yet.
  Future<void> _showHelpDialog(BuildContext context) async {
    Map<String, dynamic>? data;
    try {
      final doc = await FirebaseFirestore.instance.collection(Collections.appConfig).doc('support_contact').get();
      data = doc.data();
    } catch (_) {
      // Falls through to the generic message below - a failed fetch
      // shouldn't block someone from at least seeing that dialog.
    }

    final email = (data?['email'] as String?)?.trim() ?? '';
    final phone = (data?['phone'] as String?)?.trim() ?? '';
    final whatsapp = (data?['whatsapp'] as String?)?.trim() ?? '';
    final address = (data?['address'] as String?)?.trim() ?? '';

    if (!context.mounted) return;

    Future<void> launch(Uri uri, String failureMessage) async {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        AppFeedback.info(failureMessage);
      }
    }

    // Clickable rows (email/phone/WhatsApp) get a tinted, rounded
    // background and a trailing chevron so they visually read as
    // tappable - the plain address row below has neither, so the one
    // row with nothing to tap doesn't invite a tap.
    Widget contactRow({
      required IconData icon,
      required String label,
      String? sublabel,
      VoidCallback? onTap,
    }) {
      final row = Row(
        children: [
          Icon(icon, size: AppIconSize.i18, color: context.colors.primary),
          const SizedBox(width: AppSpacing.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(label, style: const TextStyle(fontSize: AppFontSize.f13_5)),
                if (sublabel != null)
                  Text(sublabel, style: TextStyle(fontSize: AppFontSize.f11, color: context.colors.textMuted)),
              ],
            ),
          ),
          if (onTap != null) Icon(Icons.chevron_right, size: AppIconSize.i18, color: context.colors.textDisabled),
        ],
      );

      if (onTap == null) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s4),
          child: row,
        );
      }

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.s3),
        child: Material(
          color: context.colors.primary.withValues(alpha: AppAlpha.a05),
          borderRadius: BorderRadius.circular(AppRadius.r8),
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.r8),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8, horizontal: AppSpacing.s8),
              child: row,
            ),
          ),
        ),
      );
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r16)),
        title: Text(context.l10n.dashboard_contactSupport),
        content: SizedBox(
          width: 320,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Always shown, regardless of whether any contact
              // details are configured - the statement itself already
              // names Platform Admin explicitly.
              Text(context.l10n.dashboard_supportIntro(AppInfo.name),
                  style: const TextStyle(fontSize: AppFontSize.f13_5)),
              if (email.isNotEmpty || phone.isNotEmpty || whatsapp.isNotEmpty || address.isNotEmpty) ...[
                const SizedBox(height: AppSpacing.s10),
                if (email.isNotEmpty)
                  contactRow(
                    icon: Icons.email_outlined,
                    label: email,
                    onTap: () {
                      Navigator.pop(ctx);
                      launch(AppLinks.mailto(email), context.l10n.dashboard_emailAppFailed);
                    },
                  ),
                if (phone.isNotEmpty)
                  contactRow(
                    icon: Icons.call_outlined,
                    label: phone,
                    onTap: () {
                      Navigator.pop(ctx);
                      launch(AppLinks.tel(phone), context.l10n.common_dialerFailed);
                    },
                  ),
                if (whatsapp.isNotEmpty)
                  contactRow(
                    icon: Icons.chat_outlined,
                    label: whatsapp,
                    sublabel: context.l10n.debtors_viaWhatsApp,
                    onTap: () {
                      Navigator.pop(ctx);
                      launch(AppLinks.whatsApp(whatsapp), context.l10n.debtors_whatsAppFailed);
                    },
                  ),
                if (address.isNotEmpty)
                  contactRow(icon: Icons.location_on_outlined, label: address),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l10n.common_close)),
        ],
      ),
    );
  }

  Widget _buildAlertsBell(BuildContext context) {
    final sub = Provider.of<SubscriptionProvider>(context);
    // Same thresholds as the pill/Notifications screen, so all three
    // never disagree about whether the subscription needs attention.
    final subscriptionNeedsAttention = sub.status == SubscriptionStatus.grace ||
        sub.status == SubscriptionStatus.locked ||
        ((sub.status == SubscriptionStatus.trial || sub.status == SubscriptionStatus.active) &&
            sub.daysRemaining != null &&
            sub.daysRemaining! <= 7);

    // Blue category - the same calm, non-urgent trial state shown on
    // the Dashboard banner and in the Notifications dropdown; distinct
    // from subscriptionNeedsAttention above, which only covers the
    // urgent <=7-day window.
    final isInTrialInfo = sub.isInCalmTrial; // the same definition the lists use, so a blink always has a message
    final hasNew = _hasNewUrgentSinceViewed || _hasNewPendingAssistantSinceViewed;

    // Amber category - reuses the exact same <=7-day definition
    // (subscriptionNeedsAttention) as "expiring soon" for a
    // targeted promotion, so this never disagrees with what the
    // Subscription screen itself would show.
    final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';
    final bellFeed = _bellFeedFor(facilityId);

    return StreamBuilder<Promotion?>(
      stream: streamApplicablePromotion(facilityId: facilityId, isExpiringSoon: subscriptionNeedsAttention),
      builder: (context, promoSnapshot) {
        return ListenableBuilder(
          listenable: Listenable.merge([bellFeed]),
          builder: (context, _) {
            // A promotion I removed from my notifications no longer lights
            // the accent for me (a NEW one writes a new notification).
            final promo = promoSnapshot.data;
            final hasActivePromotion = promo != null && !(bellFeed?.isPromotionDismissedForMe(promo.label) ?? false);
            // Only what is meant for me, within its lifetime, not removed, and
            // unread for ME (my own read state, NOTIF-2c), subscription alerts
            // included: read means quiet. The calm trial is the blue dot.
            final hasUnreadFacilityNotification = bellFeed?.hasUnreadAlert ?? false;

            // Cycles through whichever of the three actually apply -
            // one just blinks in place, several cycle between them,
            // so someone with an urgent issue AND an active
            // promotion sees both rather than only whichever was
            // checked first.
            final activeCategories = <Color>[
              if (hasNew || hasUnreadFacilityNotification) context.colors.dangerAccent,
              if (isInTrialInfo) context.colors.info,
              if (hasActivePromotion) context.colors.accent,
            ];

            return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  key: _bellKey,
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: context.l10n.common_notifications,
                  onPressed: () async {
                    final isWideScreen = MediaQuery.of(context).size.width >= AppBreakpoints.medium;
                    if (isWideScreen) {
                      await _showNotificationsDropdown(context);
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
                      );
                    }
                    // Notifications marks itself "viewed" on open - re-check
                    // here so the blink stops immediately on return, rather
                    // than waiting for some other reason to rebuild.
                    _refreshNotificationsViewedState();
                  },
                ),
                if (activeCategories.isNotEmpty)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: _BlinkingDot(colors: activeCategories),
                  ),
              ],
            );
          },
        );
      },
    );
  }

// DRAWER CONTENTS
Widget _buildDrawerContent() {
  final facilityProvider = Provider.of<FacilityProvider>(context);
  final selectedFacility = facilityProvider.selectedFacility;
  // Layout Fixed Mode (UI Settings) holds the sidebar open. The person's own
  // collapsed choice is left untouched, so turning the mode off puts the
  // sidebar back the way they had it.
  final bool layoutFixed = Provider.of<UiSettingsProvider>(context).layoutFixed;
  final bool collapsed = _isDrawerCollapsed && !layoutFixed;

  final bool isSmallScreen =
      MediaQuery.of(context).size.height < 600 ||
      MediaQuery.of(context).size.width < 1024;
  // Never collapse on a small screen - the drawer there is already a
  // slide-in overlay, not a permanent column, so there's no space to
  // reclaim by shrinking it.
  final bool effectivelyCollapsed = collapsed && !isSmallScreen;

  // ---------- LOGO ----------
  // Display only here - logo management now lives in View Facilities
  // (per-facility, since logo is a per-facility property, not a global
  // one), so this no longer needs to be tappable, and correctly
  // reflects whatever's actually saved (via FacilityProvider's live
  // listener) rather than a locally-picked image that was never wired
  // to that update path.
  final double logoSize = effectivelyCollapsed ? 36 : 60;
  Widget logoSection = Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: AppSpacing.s18, bottom: AppSpacing.s12),
    alignment: Alignment.center,
    child: AnimatedContainer(
      // Kept in step with the sidebar width's own animation below
      // (same duration and curve) - this shrinks at the same time as
      // the panel narrows, so the two don't visibly drift out of sync
      // mid-slide.
      duration: AppMotion.slower,
      curve: Curves.easeInOutCubic,
      width: logoSize,
      height: logoSize,
      padding: const EdgeInsets.all(AppSpacing.s4),
      decoration: BoxDecoration(
        color: _onBrandInk(context),
        borderRadius: BorderRadius.circular(AppRadius.r10),
      ),
      // BoxFit.contain rather than a forced circular crop, so a
      // rectangular or text-wordmark logo isn't cropped or distorted.
      child: (selectedFacility != null && selectedFacility['logoUrl'] != null)
          ? Image.network(
              selectedFacility['logoUrl'] as String,
              fit: BoxFit.contain,
              // _buildDrawerContent() runs on every rebuild, recreating
              // this Image.network as a fresh widget instance each
              // time - without this, Flutter shows nothing for at
              // least one frame while its ImageStream resolves, even
              // when the bytes are already cached (resolving is
              // inherently async). wasSynchronouslyLoaded is true on
              // a genuine cache hit, so this skips any transition then
              // and shows it instantly - only a real first-time
              // network load still gets a brief fade-in.
              gaplessPlayback: true,
              // Decodes directly at a small resolution rather than
              // decoding the full source image (however large it
              // actually is on Storage right now) and scaling down
              // afterward - this helps immediately with an existing,
              // already-uploaded large file, unlike the resize-on-
              // upload fix which only applies to future uploads.
              // 180px accounts for high-DPI screens showing this at
              // ~60px logical size.
              cacheWidth: 180,
              cacheHeight: 180,
              frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
                if (wasSynchronouslyLoaded) return child;
                return AnimatedOpacity(
                  opacity: frame == null ? 0 : 1,
                  duration: AppMotion.fast,
                  child: child,
                );
              },
              errorBuilder: (context, error, stackTrace) =>
                  Image.asset('assets/vetbiz_pro_logo.png', fit: BoxFit.contain),
            )
          : Image.asset('assets/vetbiz_pro_logo.png', fit: BoxFit.contain),
    ),
  );

  // ---------- DRAWER ITEMS ----------
  Widget items = Column(
    children: [
      DrawerHoverItem(
        icon: Icons.store,
        title: context.l10n.nav_stock,
        isCollapsed: effectivelyCollapsed,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => StockStoreScreen()),
          );
          _refreshDashboardData();
        },
      ),
      DrawerHoverItem(
        icon: Icons.inventory,
        title: context.l10n.nav_products,
        isCollapsed: effectivelyCollapsed,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductsScreen()),
          );
          _refreshDashboardData();
        },
      ),
      DrawerHoverItem(
        icon: Icons.attach_money,
        title: context.l10n.nav_sales,
        isCollapsed: effectivelyCollapsed,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => SalesScreen()),
          );
          _refreshDashboardData();
        },
      ),
      DrawerHoverItem(
        icon: Icons.design_services,
        title: context.l10n.nav_services,
        isCollapsed: effectivelyCollapsed,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ServicesScreen()),
          );
          _refreshDashboardData();
        },
      ),
      DrawerHoverItem(
        icon: Icons.people,
        title: context.l10n.clients_title,
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClientsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.payments,
        title: context.l10n.payments_title,
        isCollapsed: effectivelyCollapsed,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PaymentsScreen()),
          );
          _refreshDashboardData();
        },
      ),
      DrawerHoverItem(
        icon: Icons.money_off,
        title: context.l10n.nav_debtors,
        isCollapsed: effectivelyCollapsed,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => DebtorsScreen()),
          );
          _refreshDashboardData();
        },
      ),
      DrawerHoverItem(
        icon: Icons.receipt_long,
        title: context.l10n.transactions_title,
        isCollapsed: effectivelyCollapsed,
        onTap: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => TransactionScreen()),
          );
          _refreshDashboardData();
        },
      ),
      DrawerHoverItem(
        icon: Icons.summarize_outlined,
        title: context.l10n.nav_reports,
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewReportsScreen()),
        ),
      ),
    ],
  );

  // ---------- SETTINGS ----------
  Widget settings = DrawerHoverItem(
    icon: Icons.settings,
    title: context.l10n.settings_title,
    isCollapsed: effectivelyCollapsed,
    onTap: () => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SettingsScreen()),
    ),
  );

  // Same amber-tinted recipe as "Go to Facility" in Platform Admin's
  // own sidebar - reused here since this drawer has no "currently
  // selected tab" using that same color, so there's no risk of the
  // confusion that reusing it inside Platform Admin's own sidebar
  // would cause.
  Widget platformAdminItem = FutureBuilder<bool>(
    future: _isPlatformAdmin(),
    builder: (context, snapshot) {
      if (snapshot.data != true) return const SizedBox.shrink();
      final canShowLabel = !effectivelyCollapsed;
      final content = Padding(
        padding: EdgeInsets.symmetric(horizontal: effectivelyCollapsed ? AppSpacing.s4 : AppSpacing.s8),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.r8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlatformAdminHomeScreen()),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.s10, horizontal: effectivelyCollapsed ? AppSpacing.s12 : AppSpacing.s16),
            decoration: BoxDecoration(
              color: context.colors.accent.withValues(alpha: AppAlpha.a10),
              borderRadius: BorderRadius.circular(AppRadius.r8),
              border: Border.all(color: context.colors.accent.withValues(alpha: AppAlpha.a40), width: 1),
            ),
            child: Row(
              mainAxisAlignment: effectivelyCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: context.colors.accent),
                if (canShowLabel) ...[
                  const SizedBox(width: AppSpacing.s16),
                  Expanded(
                    child: Text(
                      context.l10n.nav_platformAdmin,
                      style: TextStyle(color: context.colors.onBrandSurface, fontWeight: AppFontWeight.semibold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
      if (!effectivelyCollapsed) return content;
      return Tooltip(message: context.l10n.nav_platformAdmin, waitDuration: _DrawerHoverItemState._tooltipWait, child: content);
    },
  );

  // ---------- FOOTER ----------
  Widget footer = Padding(
    padding: const EdgeInsets.symmetric(vertical: AppSpacing.s8),
    child: effectivelyCollapsed
        ? const SizedBox.shrink()
        : Text(
            '@${AppInfo.name}',
            style: TextStyle(fontSize: AppFontSize.f12, color: _onBrandInk(context)),
          ),
  );

  // ---------- FACILITY NAME ----------
  // Text label for the facility, shown below the logo - this is what
  // the old AppBar title used to show ("{name} {type} Dashboard")
  // before that was restyled; preserved here instead since the
  // sidebar's own logo area is the more natural place for it now.
  final String facilityDisplayName = selectedFacility?['name'] ?? '';
  final String facilityDisplayType = selectedFacility?['type'] ?? '';
  final String? facilityIdForTagline = selectedFacility?['id'];
  // 'Other' is the stored type, compared as stored; the type is shown through
  // its lookup.
  final String combinedNameAndType =
      (facilityDisplayType.isNotEmpty && facilityDisplayType != 'Other')
          ? context.l10n.dashboard_facilityNameType(facilityDisplayName, context.l10n.facilityTypeLabel(facilityDisplayType))
          : facilityDisplayName;
  Widget facilityNameSection = effectivelyCollapsed || facilityDisplayName.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: AppSpacing.s12),
          child: Column(
            children: [
              Text(
                combinedNameAndType,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: AppFontSize.f15, fontWeight: AppFontWeight.bold, color: _onBrandInk(context)),
              ),
              if (facilityIdForTagline != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection(Collections.facilities).doc(facilityIdForTagline).snapshots(),
                  builder: (context, snapshot) {
                    final tagline = (snapshot.data?.data() as Map<String, dynamic>?)?['tagline'] as String?;
                    if (tagline == null || tagline.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: AppSpacing.s2),
                      child: Text(
                        tagline,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: AppFontSize.f11, color: _onBrandInk(context).withValues(alpha: AppAlpha.a70)),
                      ),
                    );
                  },
                ),
            ],
          ),
        );

  // ---------- FINAL LAYOUT ----------
  Widget content = Column(
    children: [
      logoSection,
      facilityNameSection,
      Divider(thickness: 1.2, color: context.colors.onBrandSurface.withValues(alpha: AppAlpha.a50)),
      items,
      Divider(thickness: 1.2, color: context.colors.onBrandSurface.withValues(alpha: AppAlpha.a50)),
      settings,
      platformAdminItem,
    ],
  );

  return AnimatedContainer(
    // Was 200ms/easeInOut - reported as too quick/abrupt for a panel
    // this size sliding this far (72 to 250). Slower, and
    // easeInOutCubic eases in and out more gradually at both ends than
    // easeInOut (which is close to linear through its middle), reading
    // as a deliberate glide rather than a snap.
    duration: AppMotion.slower,
    curve: Curves.easeInOutCubic,
    width: effectivelyCollapsed ? 72 : 250,
    color: context.colors.brandSurface,
    child: Column(
      children: [
        Expanded(
          child: SingleChildScrollView(child: content),
        ),
        footer,
      ],
    ),
  );
}



  // --------------------- PROFILE: TOP BAR AND END DRAWER ---------------------

  Map<String, dynamic> _profileData(AsyncSnapshot<DocumentSnapshot> snapshot) {
    final raw = snapshot.data?.data();
    return (raw != null && raw is Map) ? Map<String, dynamic>.from(raw) : {};
  }

  String _profileRoleLabel(Map<String, dynamic> data) {
    if (data.isEmpty) return ''; // still loading
    final role = data[Fields.role] ?? 'Assistant';
    // A promoted Assistant is a Co-admin, not just "Admin".
    return (role == UserRole.admin.key && data['previousRole'] == UserRole.assistant.key)
        ? context.l10n.role_coAdmin
        // Capitalised first, so an unknown role still shows as before.
        : context.l10n.roleLabel(_capitalize(role));
  }

  // The person's button in both top bars (the AppBar below the large
  // breakpoint, _buildTopBar above it); a tap opens the end drawer.
  Widget _buildProfileButton() {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.s12),
      child: Builder(
        builder: (context) => StreamBuilder<DocumentSnapshot>(
          stream: userDoc.snapshots(),
          builder: (context, snapshot) {
            final data = _profileData(snapshot);
            return ProfileMenuButton(
              avatarUrl: data['avatarUrl'] as String?,
              name: (data['fullName'] ?? '').toString(),
              roleLabel: _profileRoleLabel(data),
              onTap: () => Scaffold.of(context).openEndDrawer(),
            );
          },
        ),
      ),
    );
  }


  // --------------------- END DRAWER ---------------------
  Widget _buildEndDrawerContent() {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: context.colors.brandSurface,
      foregroundColor: _onBrandInk(context),
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.s20, vertical: AppSpacing.s14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.r8)),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(WidgetState.hovered)) return context.colors.sidebarHover;
          if (states.contains(WidgetState.pressed)) return context.colors.sidebarPress;
          return null;
        },
      ),
    );

    return StreamBuilder<DocumentSnapshot>(
      stream: userDoc.snapshots(),
      builder: (context, snapshot) {
        final rawData = snapshot.data?.data();
        final Map<String, dynamic> data =
            (rawData != null && rawData is Map) ? Map<String, dynamic>.from(rawData) : {};

        final role = data[Fields.role] ?? 'Assistant';
        final avatarUrl = data['avatarUrl'] as String?;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(AppSpacing.s16),
              children: [
                // Avatar with grey border
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.s2),
                        decoration: BoxDecoration(
                          color: context.colors.borderStrong,
                          shape: BoxShape.circle,
                        ),
                        child: _profileBytes != null
                            ? CircleAvatar(
                                radius: 50, backgroundColor: context.colors.background, backgroundImage: MemoryImage(_profileBytes!))
                            : InitialsAvatar(
                                avatarUrl: avatarUrl,
                                name: data['fullName'] ?? '',
                                size: 100,
                                backgroundColor: context.colors.background,
                                foregroundColor: context.colors.primary,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: context.colors.accent,
                          child: IconButton(
                            icon: Icon(Icons.camera_alt, size: AppIconSize.i16, color: context.colors.onPrimary),
                            onPressed: pickProfileImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Divider(thickness: 1.2, color: context.colors.borderStrong),
                const SizedBox(height: AppSpacing.s12),

                // User Info
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: context.colors.textStrong),
                    children: [
                      TextSpan(text: context.l10n.dashboard_fullNameLabel, style: const TextStyle(fontWeight: AppFontWeight.bold)),
                      TextSpan(text: data['fullName'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: context.colors.textStrong),
                    children: [
                      TextSpan(text: context.l10n.dashboard_emailLabel, style: const TextStyle(fontWeight: AppFontWeight.bold)),
                      TextSpan(text: data['email'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: context.colors.textStrong),
                    children: [
                      TextSpan(text: context.l10n.dashboard_phoneLabel, style: const TextStyle(fontWeight: AppFontWeight.bold)),
                      TextSpan(text: data['phone'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(color: context.colors.textStrong),
                    children: [
                      TextSpan(text: context.l10n.dashboard_roleLabel, style: const TextStyle(fontWeight: AppFontWeight.bold)),
                      // A promoted Assistant is a Co-admin, not just "Admin".
                      TextSpan(
                          text: (role == UserRole.admin.key && data['previousRole'] == UserRole.assistant.key)
                              ? context.l10n.role_coAdmin
                              // Capitalised first, so an unknown role still shows as before.
                              : context.l10n.roleLabel(_capitalize(role))),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.s12),
                Divider(thickness: 1.2, color: context.colors.borderStrong),
                const SizedBox(height: AppSpacing.s12),

                // Buttons
                ElevatedButton(
                  style: buttonStyle,
                  child: Text(context.l10n.common_editProfile),
                  onPressed: () async {
                    final snapshot = await userDoc.get();
                    if (!snapshot.exists || !context.mounted) return;

                    final rawUserData = snapshot.data();
                    final userData = (rawUserData != null)
                        ? Map<String, dynamic>.from(rawUserData)
                        : <String, dynamic>{};

                    // A modal over the Dashboard on wide screens (full screen
                    // on a phone), like the other edit screens.
                    showEditProfileScreen(context, userData: userData);
                  },
                ),
                const SizedBox(height: AppSpacing.s12),

                if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
                  ElevatedButton(
                    style: buttonStyle,
                    child: Text(context.l10n.team_title),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManageAssistantsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),
                  ElevatedButton(
                    style: buttonStyle,
                    child: Text(context.l10n.dashboard_viewFacilities),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => FacilityScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: AppSpacing.s12),
                ],

                ElevatedButton(
                  style: buttonStyle,
                  child: Text(context.l10n.dashboard_changePassword),
                  onPressed: () {
                    final email = FirebaseAuth.instance.currentUser?.email;
                    if (email != null) _showChangePasswordDialog(email);
                  },
                ),
                if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
                  const SizedBox(height: AppSpacing.s12),
                  ElevatedButton(
                    style: buttonStyle,
                    child: Text(context.l10n.export_activityLog),
                    // Full screen, like the other drawer items (Manage Assistants,
                    // View Facilities).
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ActivityLogScreen()),
                      );
                    },
                  ),
                ],
                const SizedBox(height: AppSpacing.s12),
                Divider(thickness: 1.2, color: context.colors.borderStrong),
                const SizedBox(height: _logoutClearance),
              ],
            ),

            // Close X button
            Positioned(
              top: 16,
              right: 16,
              child: Tooltip(
                message: context.l10n.common_close,
                child: IconButton(
                  icon: Icon(Icons.close, size: AppIconSize.i32, color: context.colors.textSecondary),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Logout button
            Positioned(
              bottom: 16,
              right: 16,
              child: Tooltip(
                message: context.l10n.common_logout,
                child: InkWell(
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  hoverColor: context.colors.sidebarHover,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: context.colors.surface,
                        title: Text(context.l10n.common_logout, style: TextStyle(color: context.colors.primary)),
                        content: Text(context.l10n.dashboard_logoutConfirm),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text(context.l10n.common_cancel, style: TextStyle(color: context.colors.primary)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await forceLogoutAndShowLogin();
                            },
                            child: Text(context.l10n.common_logout, style: TextStyle(color: context.colors.danger)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Ink(
                    decoration: ShapeDecoration(
                      color: context.colors.brandSurface,
                      shape: CircleBorder(),
                    ),
                    child: Padding(
                      padding: EdgeInsets.all(AppSpacing.s8),
                      child: Icon(Icons.power_settings_new, size: AppIconSize.i16, color: context.colors.onBrandSurface),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

}
