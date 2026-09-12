import 'dart:async';
import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:flutter_speed_dial/flutter_speed_dial.dart';

import '../../providers/product_provider.dart';
import '../../providers/client_provider.dart';
import '../../providers/facility_provider.dart';
import '../../providers/debt_provider.dart';

import '../../services/auth_service.dart';
import '../../services/session_validity_service.dart';
import '../../services/dashboard_summary_service.dart';
import '../../services/sales_summary_service.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../utils/text_sanitizer.dart';

import '../../widgets/summary_card.dart';
import '../../widgets/initials_avatar.dart';

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
import '../../models/notification_model.dart';
import '../../providers/user_role_provider.dart';
import '../subscription/subscription_screen.dart';
import 'stock_alerts_screen.dart';
import 'insights_screen.dart';
import '../../utils/subscription_guard.dart';
import '../../utils/force_logout.dart';
import '../../utils/notification_seen_tracker.dart';
import '../store/stockstore_screen.dart';
import '../admin/manage_assistants_screen.dart';
import '../sales/add_sale_screen.dart';
import '../products/add_edit_product_screen.dart';
import '../services/add_edit_service_screen.dart';
import '../register_screen.dart';

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
            Icon(widget.icon, color: offWhite),
            if (canShowLabel) ...[
              const SizedBox(width: 16),
              Expanded(
                child: Opacity(
                  opacity: labelOpacity,
                  child: Text(
                    widget.title,
                    style: TextStyle(
                      color: offWhite,
                      fontWeight: FontWeight.w500,
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
      padding: EdgeInsets.symmetric(horizontal: widget.isCollapsed ? 4 : 8),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: widget.isCollapsed ? 12 : 16),
            decoration: BoxDecoration(
              color: _hovered ? Colors.teal.shade700 : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
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
      waitDuration: const Duration(milliseconds: 300),
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

/// Wraps the profile avatar with hover feedback (a ring, matching the
/// amber-on-hover convention used throughout the app) - a background
/// fill wouldn't read well on a circular avatar the way it does on a
/// button, so this uses a border instead.
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

class _HoverableProfileIcon extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;

  const _HoverableProfileIcon({required this.onTap, required this.child});

  @override
  State<_HoverableProfileIcon> createState() => _HoverableProfileIconState();
}

class _HoverableProfileIconState extends State<_HoverableProfileIcon> {
  bool _hovered = false;
  static const Color warmAmber = Color(0xFFFFB200);

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _hovered ? warmAmber : Colors.transparent,
              width: 2,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
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
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        transform: _hovered
            ? (Matrix4.identity()..scale(0.97)) // Slight shrink on hover
            : Matrix4.identity(),
        child: FloatingActionButton.extended(
          heroTag: widget.heroTag,
          backgroundColor: _hovered ? widget.hoverColor : widget.color,
          icon: Icon(widget.icon, color: Colors.white),
          label: Text(widget.label, style: const TextStyle(color: Colors.white)),
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
  final Color primaryDeepGreen = const Color(0xFF2F5D62);
  final Color warmAmber = const Color(0xFFFFB200);
  final Color offWhite = const Color(0xFFFDFDF9);

  final user = FirebaseAuth.instance.currentUser;
  late final userDoc = FirebaseFirestore.instance.collection('users').doc(user?.uid);

  Uint8List? _profileBytes; // Profile picture in memory
  final ImagePicker _picker = ImagePicker();

  String selectedFilter = 'Today';

  // null while checking, then true/false once known - starts null
  // rather than defaulting to true so the reminder banner doesn't
  // flash in incorrectly before the actual status is known, and
  // doesn't flash in a false positive before it's checked either.
  bool? _isEmailVerified;

  // Same cached check as settings_screen.dart's own _isPlatformAdmin -
  // the "Platform Admin" nav item lives here now instead, so this
  // screen needs the same check.
  bool? _isPlatformAdminCache;

  Future<bool> _isPlatformAdmin() async {
    if (_isPlatformAdminCache != null) return _isPlatformAdminCache!;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    final doc = await FirebaseFirestore.instance.collection('platform_admins').doc(user.uid).get();
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
  static const Duration _sessionCheckInterval = Duration(minutes: 10);

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
  static const Duration _subscriptionSnoozeDuration = Duration(hours: 2);
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
    _isEmailVerified = user?.emailVerified;
    Provider.of<AuthService>(context, listen: false)
        .refreshEmailVerifiedStatus()
        .then((verified) {
      if (mounted) setState(() => _isEmailVerified = verified);
    });
    _watchForNewNotifications();
  }

  Future<void> _watchForNewNotifications() async {
    final lastViewed = await NotificationSeenTracker.getLastViewedAt();
    if (!mounted) return;
    setState(() => _lastNotificationsViewedAt = lastViewed);

    _urgentWatchSub = FirebaseFirestore.instance
        .collection('public_announcements')
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
          .collection('users')
          .where('role', isEqualTo: 'assistant')
          .where('status', isEqualTo: 'pending')
          .where('facilityIds', arrayContains: facilityId)
          .snapshots()
          .listen((snapshot) {
        final isNew = _lastNotificationsViewedAt != null &&
            snapshot.docs.any((doc) {
              final ts = doc.data()['createdAt'];
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
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      final facilityIds = (userDoc.data()?['facilityIds'] as List?)?.cast<String>() ?? [];
      if (!facilityIds.contains(activeFacilityId)) {
        await forceLogoutAndShowLogin(
          message: 'You\'ve been reassigned to a different facility. Please log back in.',
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
    super.dispose();
  }

  // Period-aware dashboard figures (Total Sales, Earnings, Profit,
  // Expenses, Completed Services) - fetched from precomputed daily
  // aggregates via DashboardSummaryService, not derived from whatever
  // happens to be loaded in each provider's paginated list.
  final DashboardSummaryService _dashboardSummaryService = DashboardSummaryService();
  DashboardPeriodTotals _periodTotals = DashboardPeriodTotals.empty;
  bool _isPeriodLoading = false;
  String? _lastLoadedFacilityId;
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
  double? _chartPreviousTotal;
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
    switch (filter) {
      case 'Today':
        return 'vs Yesterday';
      case 'This Week':
        return 'vs Last Week';
      case 'This Month':
        return 'vs Last Month';
      case 'This Year':
        return 'vs Last Year';
      default:
        return 'vs Yesterday';
    }
  }

  (DateTime, DateTime) _previousPeriodRangeForFilter(String filter) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (filter) {
      case 'Today':
        final yesterday = today.subtract(const Duration(days: 1));
        return (yesterday, yesterday);
      case 'This Week':
        final startOfThisWeek = today.subtract(Duration(days: now.weekday - 1));
        final startOfLastWeek = startOfThisWeek.subtract(const Duration(days: 7));
        final endOfLastWeek = startOfThisWeek.subtract(const Duration(days: 1));
        return (startOfLastWeek, endOfLastWeek);
      case 'This Month':
        final firstOfThisMonth = DateTime(now.year, now.month, 1);
        // DateTime normalizes month: 0 to December of the previous
        // year on its own, so January correctly rolls back into last
        // December here without special-casing it.
        final firstOfLastMonth = DateTime(now.year, now.month - 1, 1);
        final lastDayOfLastMonth = firstOfThisMonth.subtract(const Duration(days: 1));
        return (firstOfLastMonth, lastDayOfLastMonth);
      case 'This Year':
        return (DateTime(now.year - 1, 1, 1), DateTime(now.year - 1, 12, 31));
      default:
        final yesterday = today.subtract(const Duration(days: 1));
        return (yesterday, yesterday);
    }
  }

  void _loadPeriodTotals(String facilityId) {
    setState(() => _isPeriodLoading = true);

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
    setState(() => _isPreviousPeriodLoading = true);

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

  void _loadTodayGlance(String facilityId) {
    setState(() => _isGlanceLoading = true);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final requestId = ++_glanceRequestId;

    Future.wait([
      SalesSummaryService().getRangeTotals(facilityId: facilityId, start: today, end: today),
      SalesSummaryService().getTotalCollected(facilityId: facilityId, start: today, end: today),
      _dashboardSummaryService.getDashboardTotals(facilityId: facilityId, start: today, end: today),
    ]).then((results) {
      // Discard if a newer facility selection has already superseded
      // this request - same reasoning as _loadPreviousPeriodTotals.
      if (requestId != _glanceRequestId) return;
      if (!mounted) return;

      final salesTotals = results[0] as Map<String, double>;
      final collected = results[1] as double;
      final dashboardTotals = results[2] as DashboardPeriodTotals;

      setState(() {
        _glanceSaleCount = (salesTotals['saleCount'] ?? 0).toInt();
        _glanceCollected = collected;
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
    setState(() => _isChartLoading = true);

    final (start, end, days) = _chartDateRange();
    final requestId = ++_chartRequestId;
    final salesService = SalesSummaryService();

    final previousEnd = start.subtract(const Duration(days: 1));
    final previousStart = previousEnd.subtract(Duration(days: days - 1));

    Future.wait([
      salesService.getDailySummaries(facilityId: facilityId, start: start, end: end),
      salesService.getDailyCollections(facilityId: facilityId, start: start, end: end),
      salesService.getRangeTotals(facilityId: facilityId, start: previousStart, end: previousEnd),
    ]).then((results) {
      if (requestId != _chartRequestId) return;
      if (!mounted) return;

      final dailySales = results[0] as List<DailySalesSummary>;
      final dailyCollections = results[1] as List<DailyCollection>;
      final previousTotals = results[2] as Map<String, double>;

      final salesByDate = {for (final s in dailySales) s.date: s.totalAmount};
      final collectedByDate = {for (final c in dailyCollections) c.date: c.totalCollected};

      String fmt(DateTime d) =>
          '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      // Every day in the range gets a point, 0 if nothing happened
      // that day - otherwise a quiet day would just be missing from
      // the chart entirely rather than showing as a dip to zero.
      final salesByDay = <double>[];
      final collectionsByDay = <double>[];
      for (int i = 0; i < days; i++) {
        final day = fmt(start.add(Duration(days: i)));
        salesByDay.add(salesByDate[day] ?? 0.0);
        collectionsByDay.add(collectedByDate[day] ?? 0.0);
      }

      setState(() {
        _chartSalesByDay = salesByDay;
        _chartCollectionsByDay = collectionsByDay;
        _chartPreviousTotal = previousTotals['totalAmount'];
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
    setState(() => _isPreviousSnapshotLoading = true);

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
        .collection('facilities')
        .doc(facilityId)
        .collection('dailySnapshots')
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
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }

  // PICK & SAVE USER PROFILE
  Future<void> pickProfileImage() async {
    if (user == null) return;

    final pickedFile = await _picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    setState(() => _profileBytes = bytes);

    try {
      final storageRef = FirebaseStorage.instance.ref().child('user_avatars/${user!.uid}.png');
      await storageRef.putData(bytes);
      final downloadUrl = await storageRef.getDownloadURL();
      await userDoc.update({'avatarUrl': downloadUrl});

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile avatar updated successfully.')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to save profile avatar.')),
      );
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
        title: Text(title, style: TextStyle(color: primaryDeepGreen)),
        content: Text(content),
        actions: [
          TextButton(
            child: Text('Cancel', style: TextStyle(color: primaryDeepGreen)),
            onPressed: () => Navigator.pop(context),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: warmAmber),
            child: Text('Confirm'),
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
        title: const Text("Reset Password"),
        content: Text("Send password reset email to $email?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: primaryDeepGreen),
            onPressed: () async {
              try {
                await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Reset link sent to $email")),
                );
              } catch (e) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text("Error: $e")),
                );
              }
            },
            child: Text("Send Link", style: TextStyle(color: offWhite)),
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
      Navigator.pushReplacementNamed(context, '/login');
    });
    return const SizedBox.shrink(); // Return empty widget temporarily
   }


    // Facility is loaded, we can safely access its fields
    final facilityName = selectedFacility['name'] ?? 'Facility';
    final currentFacilityId = selectedFacility['id'] as String?;

    // Kick off a period-totals fetch whenever the facility or the
    // selected filter chip changes (guarded so it doesn't refire on every
    // unrelated rebuild).
    if (currentFacilityId != null &&
        (_lastLoadedFacilityId != currentFacilityId || _lastLoadedFilter != selectedFilter)) {
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

    // Total product value
    double totalProductValue = productProvider.products.fold(
      0.0,
      (sum, p) => sum + (p.sellPrice * p.stockQty),
    );

    // Distinct debtors with an outstanding balance - same grouping
    // logic as the Debtors screen's own "Total Debtors" count.
    final Map<String, double> owedByClient = {};
    for (final debt in debtProvider.debts) {
      owedByClient[debt.clientId] = (owedByClient[debt.clientId] ?? 0) + debt.amountOwed;
    }
    final glanceDebtorCount = owedByClient.values.where((v) => v > 0).length;

    final formatter = NumberFormat.decimalPattern();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLargeScreen = constraints.maxWidth >= 1024;

        return Scaffold(
          backgroundColor: offWhite,
          appBar: isLargeScreen ? null : AppBar(
            backgroundColor: Colors.white,
            elevation: 1,
            centerTitle: false,
            iconTheme: const IconThemeData(color: Colors.black87),
            leading: isLargeScreen
                ? IconButton(
                    icon: Icon(_isDrawerCollapsed ? Icons.menu_open : Icons.menu, color: Colors.black87, size: 22),
                    tooltip: _isDrawerCollapsed ? 'Expand menu' : 'Collapse menu',
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
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: offWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Search anything...',
                            style: TextStyle(fontSize: 13, color: Colors.grey[500])),
                      ),
                      Text('Ctrl+K', style: TextStyle(fontSize: 11, color: Colors.grey[400])),
                    ],
                  ),
                ),
              _buildAlertsBell(context),
              // No help/support screen exists yet - shows a lightweight
              // dialog with app info rather than linking to a page that
              // doesn't exist.
              IconButton(
                icon: const Icon(Icons.help_outline, color: Colors.black87, size: 22),
                tooltip: 'Help',
                onPressed: () => showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('VetBiz Pro'),
                    content: const Text('For help or support, please reach out to your account administrator.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: Builder(
                  builder: (context) => _HoverableProfileIcon(
                    onTap: () => Scaffold.of(context).openEndDrawer(),
                    child: StreamBuilder<DocumentSnapshot>(
                      stream: userDoc.snapshots(),
                      builder: (context, snapshot) {
                        final rawData = snapshot.data?.data();
                        final Map<String, dynamic> data =
                            (rawData != null && rawData is Map)
                                ? Map<String, dynamic>.from(rawData)
                                : {};
                        final avatarUrl = data['avatarUrl'] as String?;
                        final fullNameForAvatar = data['fullName'] ?? '';

                        final avatar = _profileBytes != null
                            ? CircleAvatar(radius: 16, backgroundImage: MemoryImage(_profileBytes!))
                            : InitialsAvatar(
                                avatarUrl: avatarUrl,
                                name: fullNameForAvatar,
                                size: 32,
                                backgroundColor: primaryDeepGreen.withValues(alpha: 0.12),
                                foregroundColor: primaryDeepGreen,
                              );

                        if (!isLargeScreen) return avatar;

                        return Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            avatar,
                            const SizedBox(width: 8),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 110),
                              child: Text(
                                fullNameForAvatar.isNotEmpty ? fullNameForAvatar : 'Account',
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black54),
                          ],
                        );
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          drawer: isLargeScreen ? null : Drawer(child: _buildDrawerContent()),
          endDrawer: Drawer(child: _buildEndDrawerContent()),
          body: Column(
            children: [
              Container(height: 1.2, width: double.infinity, color: Colors.grey.shade400),
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
                                  color: offWhite,
                                  child: Padding(
                                  padding: const EdgeInsets.all(16),
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
                                        Text('${greetingTime()}, $fullName',
                                            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                                        const SizedBox(height: 2),
                                        Text("Here's how $facilityName is doing today.",
                                            style: TextStyle(fontSize: 13, color: Colors.grey[600])),
                                      ],
                                    );

                                    final dateTimeRow = StreamBuilder(
                                      stream: Stream.periodic(const Duration(seconds: 1)),
                                      builder: (context, _) {
                                        final now = DateTime.now();
                                        return Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            PopupMenuButton<String>(
                                              tooltip: 'Change period',
                                              onSelected: (val) => setState(() => selectedFilter = val),
                                              itemBuilder: (context) => ['Today', 'This Week', 'This Month', 'This Year']
                                                  .map((f) => PopupMenuItem(value: f, child: Text(f)))
                                                  .toList(),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(Icons.calendar_today_outlined, size: 14, color: Colors.grey[500]),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    selectedFilter == 'Today'
                                                        ? DateFormat('EEE, dd MMM yyyy').format(now)
                                                        : selectedFilter,
                                                    style: TextStyle(fontSize: 12.5, color: Colors.grey[600]),
                                                  ),
                                                  const SizedBox(width: 2),
                                                  Icon(Icons.arrow_drop_down, size: 16, color: Colors.grey[500]),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(width: 14),
                                            Icon(Icons.access_time, size: 14, color: Colors.grey[500]),
                                            const SizedBox(width: 6),
                                            Text(DateFormat('hh:mm a').format(now),
                                                style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
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
                                        const SizedBox(height: 8),
                                        dateTimeRow,
                                      ],
                                    );
                                  },
                                ),
                                const SizedBox(height: 16),
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
                                        title: 'Total Product Value',
                                        value: 'Tsh ${formatter.format(productProvider.totalProductValue)}',
                                        icon: Icons.inventory,
                                        color: primaryDeepGreen,
                                        shadow: true,
                                        subtitle: 'as of now',
                                        trend: KpiTrend(
                                          currentValue: productProvider.totalProductValue,
                                          previousValue:
                                              (_previousSnapshot?['totalProductValue'] as num?)?.toDouble() ?? 0,
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => 'Tsh ${formatter.format(v)}',
                                          isLoading: _isPreviousSnapshotLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: 'Total Sales ($selectedFilter)',
                                        value: 'Tsh ${formatter.format(_periodTotals.totalSales)}',
                                        icon: Icons.shopping_cart,
                                        color: warmAmber,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        trend: KpiTrend(
                                          currentValue: _periodTotals.totalSales,
                                          previousValue: _previousPeriodTotals.totalSales,
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => 'Tsh ${formatter.format(v)}',
                                          isLoading: _isPreviousPeriodLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: 'Total Earnings ($selectedFilter)',
                                        value: 'Tsh ${formatter.format(_periodTotals.totalEarnings)}',
                                        icon: Icons.attach_money,
                                        color: primaryDeepGreen,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        trend: KpiTrend(
                                          currentValue: _periodTotals.totalEarnings,
                                          previousValue: _previousPeriodTotals.totalEarnings,
                                          higherIsBetter: true,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => 'Tsh ${formatter.format(v)}',
                                          isLoading: _isPreviousPeriodLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: 'Total Profit ($selectedFilter)',
                                        value: Provider.of<UserRoleProvider>(context).isAdmin
                                            ? 'Tsh ${formatter.format(_periodTotals.totalProfit)}'
                                            : '*****',
                                        icon: Icons.trending_up,
                                        color: primaryDeepGreen,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                        // Hidden entirely for non-admins, same
                                        // as the value itself - a trend arrow
                                        // would still leak directional profit
                                        // information even with the figure
                                        // masked.
                                        trend: Provider.of<UserRoleProvider>(context).isAdmin
                                            ? KpiTrend(
                                                currentValue: _periodTotals.totalProfit,
                                                previousValue: _previousPeriodTotals.totalProfit,
                                                higherIsBetter: true,
                                                comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                                formatChange: (v) => 'Tsh ${formatter.format(v)}',
                                                isLoading: _isPreviousPeriodLoading,
                                              )
                                            : null,
                                      ),
                                      SummaryCard(
                                        title: 'Total Expenses ($selectedFilter)',
                                        value: 'Tsh ${formatter.format(_periodTotals.totalExpenses)}',
                                        icon: Icons.trending_down,
                                        color: Colors.red,
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
                                          formatChange: (v) => 'Tsh ${formatter.format(v)}',
                                          isLoading: _isPreviousPeriodLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: 'Outstanding Payment',
                                        value: 'Tsh ${formatter.format(debtProvider.totalOutstanding())}',
                                        icon: Icons.account_balance_wallet,
                                        color: warmAmber,
                                        shadow: true,
                                        subtitle: 'as of now',
                                        trend: KpiTrend(
                                          currentValue: debtProvider.totalOutstanding(),
                                          previousValue:
                                              (_previousSnapshot?['totalOutstanding'] as num?)?.toDouble() ?? 0,
                                          // Rising debt owed is the bad
                                          // outcome here too.
                                          higherIsBetter: false,
                                          comparisonLabel: _comparisonLabelForFilter(selectedFilter),
                                          formatChange: (v) => 'Tsh ${formatter.format(v)}',
                                          isLoading: _isPreviousSnapshotLoading,
                                        ),
                                      ),
                                      SummaryCard(
                                        title: 'Total Clients',
                                        value: '${clientProvider.clients.length}',
                                        icon: Icons.people,
                                        color: warmAmber,
                                        shadow: true,
                                        subtitle: 'as of now',
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
                                        title: 'Completed Services ($selectedFilter)',
                                        value: '${_periodTotals.completedServicesCount}',
                                        icon: Icons.design_services,
                                        color: const Color(0xFF3D5A80),
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
                                    mainAxisExtent: 118,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                                  itemCount: cards.length,
                                  itemBuilder: (context, index) => cards[index],
                                );
                              },
                            ),
                            const SizedBox(height: 16),
                            _buildTodayGlanceStrip(glanceDebtorCount),
                            const SizedBox(height: 16),
                            if (isLargeScreen)
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(flex: 2, child: _buildSalesRevenueChart()),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildRecentActivityFeed()),
                                ],
                              )
                            else ...[
                              _buildSalesRevenueChart(),
                              const SizedBox(height: 16),
                              _buildRecentActivityFeed(),
                            ],
                            const SizedBox(height: 16),
                            _buildQuickActionCards(context),
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
    final isInTrialInfo = sub.status == SubscriptionStatus.trial && !needsAttention;

    final isSnoozed = _subscriptionSnoozedUntil != null &&
        DateTime.now().isBefore(_subscriptionSnoozedUntil!);
    final shouldShow = (needsAttention || isInTrialInfo) && !isSnoozed && _subscriptionPillDelayPassed;

    final isLocked = sub.status == SubscriptionStatus.locked;
    final isGrace = sub.status == SubscriptionStatus.grace;
    final isTrial = sub.status == SubscriptionStatus.trial;
    // The accent - carried by the icon, the text, and a thin border -
    // rather than a full background fill. Same deepened, burnt-amber
    // reasoning as before: the brand's own warmAmber is too close to
    // yellow to read cleanly as an accent on a cream background.
    const Color deepAmber = Color(0xFFC77800);
    final accent = isLocked ? Colors.redAccent : (isInTrialInfo ? Colors.blue : deepAmber);
    const Color cream = Color(0xFFFFF6E7);

    // Full sentence now that this sits in its own row above the filter
    // chips, rather than the shortened version needed when it was
    // squeezed inline next to Insights.
    String message;
    if (isLocked) {
      message = isTrial
          ? 'Your trial has ended. The app is in read-only mode.'
          : 'Your subscription has expired. The app is in read-only mode.';
    } else if (isGrace) {
      message = isTrial
          ? 'Your trial has ended. You have a few days of grace before read-only mode begins.'
          : 'Your subscription has expired. You have a few days of grace before read-only mode begins.';
    } else if (isInTrialInfo) {
      // A legacy facility with no trial/subscription date recorded at
      // all reaches this branch with daysRemaining null - shown as an
      // open-ended trial rather than ever interpolating "null" into
      // the sentence.
      message = sub.daysRemaining != null
          ? "You're on a free trial - ${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'} left."
          : "You're on a free trial.";
    } else if (isTrial) {
      message = sub.daysRemaining != null
          ? 'Your trial expires in ${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'}.'
          : 'Your trial is active.';
    } else {
      message = sub.daysRemaining != null
          ? 'Your subscription expires in ${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'}.'
          : 'Your subscription is active.';
    }

    final isAdmin = Provider.of<UserRoleProvider>(context).isAdmin;

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 550),
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
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: cream.withValues(alpha: 0.92),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: accent.withValues(alpha: 0.35)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 6, offset: const Offset(0, 2)),
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
                    size: 16,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.black87, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () => showSubscriptionScreen(context),
                      child: Text(
                        isInTrialInfo ? 'View Plans' : 'Renew',
                        style: TextStyle(
                          color: accent,
                          fontSize: 12.5,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ] else ...[
                    const SizedBox(width: 8),
                    Text('· Ask your admin',
                        style: TextStyle(color: Colors.grey[600], fontSize: 11.5, fontStyle: FontStyle.italic)),
                  ],
                  // Snoozes rather than dismisses permanently - see the
                  // note on _subscriptionSnoozeDuration above for why.
                  const SizedBox(width: 4),
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: _snoozeSubscriptionBanner,
                    child: Padding(
                      padding: const EdgeInsets.all(4),
                      child: Icon(Icons.close, size: 15, color: Colors.grey[500]),
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
      barrierLabel: 'Notifications',
      barrierColor: Colors.transparent,
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (context, animation, secondaryAnimation) {
        return Stack(
          children: [
            Positioned(
              top: bellPosition.dy + bellSize.height + 8,
              left: left,
              child: Material(
                elevation: 8,
                borderRadius: BorderRadius.circular(12),
                clipBehavior: Clip.antiAlias,
                child: SizedBox(
                  width: panelWidth,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxHeight: screenSize.height * 0.75),
                    child: const StockAlertsScreen(isDropdown: true),
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

  IconData _activityIcon(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'products':
        return Icons.inventory_2;
      case 'inventory move':
        return Icons.swap_horiz;
      case 'sales':
        return Icons.shopping_cart;
      case 'services':
        return Icons.build;
      case 'clients':
        return Icons.people;
      case 'debtors':
        return Icons.account_balance_wallet;
      case 'settings':
        return Icons.settings;
      case 'admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.info;
    }
  }

  Color _activityColor(String actionType) {
    switch (actionType.toLowerCase()) {
      case 'inventory move':
        return Colors.blue;
      case 'products':
        return Colors.green;
      case 'sales':
        return warmAmber;
      case 'services':
        return Colors.purple;
      case 'clients':
        return Colors.teal;
      case 'debtors':
        return Colors.orange;
      case 'settings':
        return Colors.grey;
      case 'admin':
        return Colors.red;
      default:
        return primaryDeepGreen;
    }
  }

  Widget _buildRecentActivityFeed() {
    final facilityId = _lastLoadedFacilityId;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.history, size: 18, color: primaryDeepGreen),
                  const SizedBox(width: 8),
                  const Text('Recent Activity', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                ],
              ),
              TextButton(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ActivityLogScreen())),
                child: const Text('View All'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (facilityId == null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(child: Text('No activity yet.', style: TextStyle(color: Colors.grey[600]))),
            )
          else
            StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('facilities')
                  .doc(facilityId)
                  .collection('activity_logs')
                  .orderBy('timestamp', descending: true)
                  .limit(5)
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                  );
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text('No activity yet.', style: TextStyle(color: Colors.grey[600]))),
                  );
                }
                return Column(
                  children: [
                    for (int i = 0; i < docs.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: Colors.grey.withValues(alpha: 0.15)),
                      _activityTile(docs[i].data() as Map<String, dynamic>),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _activityTile(Map<String, dynamic> data) {
    final actionType = (data['actionType'] as String?) ?? '';
    final description = sanitizeForDisplay((data['description'] as String?) ?? '');
    final timestamp = data['timestamp'];
    String timeStr = '';
    if (timestamp is Timestamp) {
      timeStr = DateFormat('hh:mm a').format(timestamp.toDate());
    }
    final color = _activityColor(actionType);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
            child: Icon(_activityIcon(actionType), size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(description, style: const TextStyle(fontSize: 12.5), maxLines: 2, overflow: TextOverflow.ellipsis),
          ),
          const SizedBox(width: 8),
          Text(timeStr, style: TextStyle(fontSize: 11, color: Colors.grey[500])),
        ],
      ),
    );
  }

  Widget _buildSalesRevenueChart() {
    final moneyFormat = NumberFormat.currency(locale: 'en_US', symbol: 'Tsh ', decimalDigits: 0);
    final salesByDay = _chartSalesByDay;
    final collectionsByDay = _chartCollectionsByDay;
    final hasData = salesByDay != null && collectionsByDay != null;

    final currentTotal = hasData ? salesByDay.fold<double>(0, (a, b) => a + b) : 0.0;
    final previousTotal = _chartPreviousTotal;
    double? trendPercent;
    if (previousTotal != null && previousTotal > 0) {
      trendPercent = ((currentTotal - previousTotal) / previousTotal) * 100;
    }

    final (start, _, days) = _chartDateRange();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.show_chart, size: 18, color: primaryDeepGreen),
                  const SizedBox(width: 8),
                  const Text('Sales & Revenue Overview', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                height: 36,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _chartPeriod,
                    items: const ['Last 7 days', 'Last 30 days']
                        .map((p) => DropdownMenuItem(value: p, child: Text(p, style: const TextStyle(fontSize: 13))))
                        .toList(),
                    onChanged: (val) {
                      if (val == null) return;
                      setState(() => _chartPeriod = val);
                      final facilityId = _lastLoadedFacilityId;
                      if (facilityId != null) _loadChartData(facilityId);
                    },
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (!hasData && _isChartLoading)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 40),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(moneyFormat.format(currentTotal),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.black87)),
                    Text('Total Revenue', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
                if (trendPercent != null) ...[
                  const SizedBox(width: 12),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Icon(trendPercent >= 0 ? Icons.arrow_upward : Icons.arrow_downward,
                            size: 14, color: trendPercent >= 0 ? Colors.green : Colors.red),
                        Text('${trendPercent.abs().toStringAsFixed(1)}% vs last period',
                            style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: trendPercent >= 0 ? Colors.green : Colors.red)),
                      ],
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 220,
              child: !hasData || (salesByDay.every((v) => v == 0) && collectionsByDay.every((v) => v == 0))
                  ? Center(child: Text('No activity in this period.', style: TextStyle(color: Colors.grey[600])))
                  : LineChart(
                      LineChartData(
                        gridData: const FlGridData(show: true, drawVerticalLine: false),
                        borderData: FlBorderData(show: true, border: Border.all(color: Colors.grey.shade300)),
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final day = start.add(Duration(days: spot.x.toInt()));
                                final label = spot.barIndex == 0 ? 'Sales' : 'Collections';
                                return LineTooltipItem(
                                  '${DateFormat('d MMM').format(day)}\n$label: ${moneyFormat.format(spot.y)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                                );
                              }).toList();
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 48,
                              getTitlesWidget: (value, meta) =>
                                  Text(moneyFormat.format(value), style: const TextStyle(fontSize: 9)),
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              interval: days > 7 ? 5 : 1,
                              getTitlesWidget: (value, meta) {
                                final day = start.add(Duration(days: value.toInt()));
                                return Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Text(DateFormat('d MMM').format(day), style: const TextStyle(fontSize: 9)),
                                );
                              },
                            ),
                          ),
                        ),
                        lineBarsData: [
                          LineChartBarData(
                            spots: [for (int i = 0; i < salesByDay.length; i++) FlSpot(i.toDouble(), salesByDay[i])],
                            isCurved: true,
                            color: primaryDeepGreen,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: primaryDeepGreen.withValues(alpha: 0.1)),
                          ),
                          LineChartBarData(
                            spots: [for (int i = 0; i < collectionsByDay.length; i++) FlSpot(i.toDouble(), collectionsByDay[i])],
                            isCurved: true,
                            color: warmAmber,
                            barWidth: 3,
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: true, color: warmAmber.withValues(alpha: 0.1)),
                          ),
                        ],
                      ),
                    ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _chartLegendItem(primaryDeepGreen, 'Sales (Tsh)'),
                const SizedBox(width: 20),
                _chartLegendItem(warmAmber, 'Collections (Tsh)'),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _chartLegendItem(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
      ],
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Container(
      height: 72,
      padding: const EdgeInsets.only(left: 16, right: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey.withValues(alpha: 0.2))),
      ),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            icon: Icon(_isDrawerCollapsed ? Icons.menu_open : Icons.menu, color: Colors.black87, size: 22),
            tooltip: _isDrawerCollapsed ? 'Expand menu' : 'Collapse menu',
            onPressed: _toggleDrawerCollapsed,
          ),
          const Spacer(),
          Container(
            width: 260,
            margin: const EdgeInsets.only(right: 12),
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
                      subtitle: 'Product',
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
                      subtitle: 'Client \u2022 ${c.phone}',
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
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: offWhite,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.grey.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, size: 18, color: Colors.grey[500]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: controller,
                          focusNode: focusNode,
                          style: const TextStyle(fontSize: 13),
                          decoration: InputDecoration.collapsed(
                            hintText: 'Search products or clients...',
                            hintStyle: TextStyle(fontSize: 13, color: Colors.grey[500]),
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
                    elevation: 4,
                    borderRadius: BorderRadius.circular(8),
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
                            leading: Icon(r.icon, size: 18, color: primaryDeepGreen),
                            title: Text(r.title, style: const TextStyle(fontSize: 13)),
                            subtitle: Text(r.subtitle, style: const TextStyle(fontSize: 11)),
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
          // No help/support screen exists yet - shows a lightweight
          // dialog with app info rather than linking to a page that
          // doesn't exist.
          IconButton(
            icon: const Icon(Icons.help_outline, color: Colors.black87, size: 22),
            tooltip: 'Help',
            onPressed: () => showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Text('VetBiz Pro'),
                content: const Text('For help or support, please reach out to your account administrator.'),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
                ],
              ),
            ),
          ),
          const SizedBox(width: 4),
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Builder(
              builder: (context) => _HoverableProfileIcon(
                onTap: () => Scaffold.of(context).openEndDrawer(),
                child: StreamBuilder<DocumentSnapshot>(
                  stream: userDoc.snapshots(),
                  builder: (context, snapshot) {
                    final rawData = snapshot.data?.data();
                    final Map<String, dynamic> data =
                        (rawData != null && rawData is Map)
                            ? Map<String, dynamic>.from(rawData)
                            : {};
                    final avatarUrl = data['avatarUrl'] as String?;
                    final fullNameForAvatar = data['fullName'] ?? '';

                    final avatar = _profileBytes != null
                        ? CircleAvatar(radius: 16, backgroundImage: MemoryImage(_profileBytes!))
                        : InitialsAvatar(
                            avatarUrl: avatarUrl,
                            name: fullNameForAvatar,
                            size: 32,
                            backgroundColor: primaryDeepGreen.withValues(alpha: 0.12),
                            foregroundColor: primaryDeepGreen,
                          );

                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        avatar,
                        const SizedBox(width: 8),
                        ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 110),
                          child: Text(
                            fullNameForAvatar.isNotEmpty ? fullNameForAvatar : 'Account',
                            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.black87),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const Icon(Icons.keyboard_arrow_down, size: 18, color: Colors.black54),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayGlanceStrip(int debtorCount) {
    final formatter = NumberFormat.decimalPattern();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.15)),
      ),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 24,
        runSpacing: 10,
        children: [
          Text('Today at a Glance', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5, color: Colors.black87)),
          if (_glanceSaleCount == null && _isGlanceLoading)
            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
          else ...[
            _glanceStat(Icons.shopping_cart_outlined, '${_glanceSaleCount ?? 0}', 'Sales', primaryDeepGreen),
            _glanceStat(Icons.build_outlined, '${_glanceServiceCount ?? 0}', 'Services', const Color(0xFF3D5A80)),
            _glanceStat(Icons.payments_outlined, 'Tsh ${formatter.format(_glanceCollected ?? 0)}', 'Collected', primaryDeepGreen),
          ],
          _glanceStat(Icons.folder_outlined, '$debtorCount', debtorCount == 1 ? 'Outstanding Debt' : 'Outstanding Debts', warmAmber),
          OutlinedButton.icon(
            onPressed: () => showInsightsScreen(context),
            icon: Icon(Icons.insights, size: 16, color: primaryDeepGreen),
            label: Text('Insights', style: TextStyle(color: primaryDeepGreen)),
            style: OutlinedButton.styleFrom(side: BorderSide(color: primaryDeepGreen)),
          ),
        ],
      ),
    );
  }

  Widget _glanceStat(IconData icon, String value, String label, Color color) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 12.5, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildQuickActionCards(BuildContext context) {
    final isLargeScreen = MediaQuery.of(context).size.width >= 1024;

    final cards = [
      _quickActionCard(
        icon: Icons.add_shopping_cart,
        title: 'Record Sale',
        subtitle: 'Create a new sale',
        backgroundColor: primaryDeepGreen,
        accentColor: primaryDeepGreen,
        isDark: true,
        onTap: () => navigateOrShowLockedDialog(
          context,
          const AddSaleScreen(),
          onNavigate: () => showAddSaleScreen(context),
        ),
      ),
      _quickActionCard(
        icon: Icons.design_services,
        title: 'Record Visit',
        subtitle: 'Add a new service record',
        backgroundColor: const Color(0xFFE3F0EC),
        accentColor: primaryDeepGreen,
        isDark: false,
        onTap: () => navigateOrShowLockedDialog(
          context,
          const AddEditServiceScreen(),
          onNavigate: () => showAddEditServiceScreen(context),
        ),
      ),
      _quickActionCard(
        icon: Icons.add_box,
        title: 'Add Product',
        subtitle: 'Add new product to store',
        backgroundColor: const Color(0xFFFCEFD9),
        accentColor: warmAmber,
        isDark: false,
        onTap: () => showAddEditProductScreen(context),
      ),
    ];

    if (isLargeScreen) {
      return Row(
        children: [
          for (int i = 0; i < cards.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: cards[i]),
          ],
        ],
      );
    }
    return Column(
      children: [
        for (int i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 12),
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
    final textColor = isDark ? Colors.white : Colors.black87;
    final subtitleColor = isDark ? Colors.white.withValues(alpha: 0.85) : Colors.grey[700];
    final iconCircleColor = isDark ? Colors.white.withValues(alpha: 0.18) : accentColor.withValues(alpha: 0.15);
    final iconColor = isDark ? Colors.white : accentColor;
    final chevronColor = isDark ? Colors.white : accentColor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconCircleColor,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  Text(subtitle, style: TextStyle(color: subtitleColor, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: chevronColor, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildAlertsBell(BuildContext context) {
    final products = Provider.of<ProductProvider>(context).products;
    final hasStockAlerts = StockAlertsScreen.hasAnyAlert(products);

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
    final isInTrialInfo = sub.status == SubscriptionStatus.trial && !subscriptionNeedsAttention;

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('public_announcements')
          .where('urgent', isEqualTo: true)
          .snapshots(),
      builder: (context, snapshot) {
        final hasUrgentAnnouncement = (snapshot.data?.docs ?? []).any((doc) {
          final data = doc.data() as Map<String, dynamic>;
          return data['hidden'] != true;
        });
        final hasAlerts = hasStockAlerts || hasUrgentAnnouncement || _isEmailVerified == false;
        // Subscription deliberately blinks rather than joining the
        // steady hasAlerts group, and deliberately isn't gated by
        // "since Notifications was last viewed" the way the other two
        // are - it's not a one-off event to acknowledge, it's an
        // ongoing problem that should keep drawing the eye for as long
        // as it's actually true, independent of the floating pill's
        // own snooze state (dismissing that pill never silences this).
        final hasNew = _hasNewUrgentSinceViewed || _hasNewPendingAssistantSinceViewed || subscriptionNeedsAttention;

        // Amber category - reuses the exact same <=7-day definition
        // (subscriptionNeedsAttention) as "expiring soon" for a
        // targeted promotion, so this never disagrees with what the
        // Subscription screen itself would show.
        final facilityId = Provider.of<FacilityProvider>(context, listen: false).selectedFacilityId ?? '';

        return StreamBuilder<Promotion?>(
          stream: streamApplicablePromotion(facilityId: facilityId, isExpiringSoon: subscriptionNeedsAttention),
          builder: (context, promoSnapshot) {
            final hasActivePromotion = promoSnapshot.data != null;

            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: facilityId.isEmpty
                  ? null
                  : FirebaseFirestore.instance
                      .collection('facilities')
                      .doc(facilityId)
                      .collection('notifications')
                      .orderBy('createdAt', descending: true)
                      .limit(50)
                      .snapshots(),
              builder: (context, notifSnapshot) {
                final hasUnreadFacilityNotification = (notifSnapshot.data?.docs ?? [])
                    .map(FacilityNotification.fromFirestore)
                    .any((n) => !n.isRead && !n.isExpired);

                // Cycles through whichever of the four actually apply -
                // one just blinks in place, several cycle between them,
                // so someone with an urgent issue AND an active
                // promotion sees both rather than only whichever was
                // checked first.
                final activeCategories = <Color>[
                  if (hasNew || hasUnreadFacilityNotification) Colors.redAccent,
                  if (isInTrialInfo) Colors.blue,
                  if (hasActivePromotion) warmAmber,
                ];

                return Stack(
              clipBehavior: Clip.none,
              children: [
                IconButton(
                  key: _bellKey,
                  icon: const Icon(Icons.notifications_outlined),
                  tooltip: 'Notifications',
                  onPressed: () async {
                    final isWideScreen = MediaQuery.of(context).size.width >= 900;
                    if (isWideScreen) {
                      await _showNotificationsDropdown(context);
                    } else {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const StockAlertsScreen()),
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
                  )
                else if (hasAlerts)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      width: 9,
                      height: 9,
                      decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
                    ),
                  ),
              ],
            );
              },
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
  final bool collapsed = _isDrawerCollapsed;

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
  final double _logoSize = effectivelyCollapsed ? 36 : 60;
  Widget logoSection = Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 18, bottom: 12),
    alignment: Alignment.center,
    child: Container(
      width: _logoSize,
      height: _logoSize,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: offWhite,
        borderRadius: BorderRadius.circular(10),
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
                  duration: const Duration(milliseconds: 150),
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
        title: 'Stock Store',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => StockStoreScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.inventory,
        title: 'Products',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ProductsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.attach_money,
        title: 'Sales',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => SalesScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.design_services,
        title: 'Service Records',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ServicesScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.payments,
        title: 'Payments',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const PaymentsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.money_off,
        title: 'Debtors',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DebtorsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.receipt_long,
        title: 'Transactions',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => TransactionScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.summarize_outlined,
        title: 'View Reports',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ViewReportsScreen()),
        ),
      ),
      DrawerHoverItem(
        icon: Icons.people,
        title: 'Clients',
        isCollapsed: effectivelyCollapsed,
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ClientsScreen()),
        ),
      ),
    ],
  );

  // ---------- SETTINGS ----------
  Widget settings = DrawerHoverItem(
    icon: Icons.settings,
    title: 'Settings',
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
        padding: EdgeInsets.symmetric(horizontal: effectivelyCollapsed ? 4 : 8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const PlatformAdminHomeScreen()),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 10, horizontal: effectivelyCollapsed ? 12 : 16),
            decoration: BoxDecoration(
              color: warmAmber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: warmAmber.withValues(alpha: 0.35), width: 1),
            ),
            child: Row(
              mainAxisAlignment: effectivelyCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
              children: [
                Icon(Icons.admin_panel_settings_outlined, color: warmAmber),
                if (canShowLabel) ...[
                  const SizedBox(width: 16),
                  const Expanded(
                    child: Text(
                      'Platform Admin',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
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
      return Tooltip(message: 'Platform Admin', waitDuration: const Duration(milliseconds: 300), child: content);
    },
  );

  // ---------- FOOTER ----------
  Widget footer = Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: effectivelyCollapsed
        ? const SizedBox.shrink()
        : Text(
            '@VetBiz Pro',
            style: TextStyle(fontSize: 12, color: offWhite),
          ),
  );

  // ---------- FACILITY NAME ----------
  // Text label for the facility, shown below the logo - this is what
  // the old AppBar title used to show ("{name} {type} Dashboard")
  // before that was restyled; preserved here instead since the
  // sidebar's own logo area is the more natural place for it now.
  final String facilityDisplayName = selectedFacility?['name'] as String? ?? '';
  final String facilityDisplayType = selectedFacility?['type'] as String? ?? '';
  final String? facilityIdForTagline = selectedFacility?['id'] as String?;
  final String combinedNameAndType =
      (facilityDisplayType.isNotEmpty && facilityDisplayType != 'Other')
          ? '$facilityDisplayName $facilityDisplayType'
          : facilityDisplayName;
  Widget facilityNameSection = effectivelyCollapsed || facilityDisplayName.isEmpty
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Column(
            children: [
              Text(
                combinedNameAndType,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: offWhite),
              ),
              if (facilityIdForTagline != null)
                StreamBuilder<DocumentSnapshot>(
                  stream: FirebaseFirestore.instance.collection('facilities').doc(facilityIdForTagline).snapshots(),
                  builder: (context, snapshot) {
                    final tagline = (snapshot.data?.data() as Map<String, dynamic>?)?['tagline'] as String?;
                    if (tagline == null || tagline.isEmpty) return const SizedBox.shrink();
                    return Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        tagline,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 11, color: offWhite.withValues(alpha: 0.7)),
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
      Divider(thickness: 1.2, color: Colors.white54),
      items,
      Divider(thickness: 1.2, color: Colors.white54),
      settings,
      platformAdminItem,
    ],
  );

  return AnimatedContainer(
    duration: const Duration(milliseconds: 200),
    curve: Curves.easeInOut,
    width: effectivelyCollapsed ? 72 : 250,
    color: primaryDeepGreen,
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



  // --------------------- END DRAWER ---------------------
  Widget _buildEndDrawerContent() {
    final buttonStyle = ElevatedButton.styleFrom(
      backgroundColor: primaryDeepGreen,
      foregroundColor: offWhite,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    ).copyWith(
      overlayColor: WidgetStateProperty.resolveWith<Color?>(
        (states) {
          if (states.contains(WidgetState.hovered)) return Colors.teal.shade700;
          if (states.contains(WidgetState.pressed)) return Colors.teal.shade800;
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

        final role = data['role'] ?? 'Assistant';
        final avatarUrl = data['avatarUrl'] as String?;

        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Avatar with grey border
                Center(
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(2),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade400,
                          shape: BoxShape.circle,
                        ),
                        child: _profileBytes != null
                            ? CircleAvatar(
                                radius: 50, backgroundColor: offWhite, backgroundImage: MemoryImage(_profileBytes!))
                            : InitialsAvatar(
                                avatarUrl: avatarUrl,
                                name: data['fullName'] ?? '',
                                size: 100,
                                backgroundColor: offWhite,
                                foregroundColor: primaryDeepGreen,
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: warmAmber,
                          child: IconButton(
                            icon: const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                            onPressed: pickProfileImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(thickness: 1.2, color: Colors.grey.shade400),
                const SizedBox(height: 12),

                // User Info
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Full Name: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: data['fullName'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Email: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: data['email'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Phone: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: data['phone'] ?? ''),
                    ],
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.black),
                    children: [
                      const TextSpan(text: "Role: ", style: TextStyle(fontWeight: FontWeight.bold)),
                      TextSpan(text: _capitalize(role)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                Divider(thickness: 1.2, color: Colors.grey.shade400),
                const SizedBox(height: 12),

                // Buttons
                ElevatedButton(
                  style: buttonStyle,
                  child: const Text('Edit Profile'),
                  onPressed: () async {
                    final snapshot = await userDoc.get();
                    if (!snapshot.exists) return;

                    final rawUserData = snapshot.data();
                    final userData = (rawUserData != null)
                        ? Map<String, dynamic>.from(rawUserData)
                        : <String, dynamic>{};

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => RegisterScreen(
                          userData: userData,
                          isUpdating: true,
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 12),

                if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
                  ElevatedButton(
                    style: buttonStyle,
                    child: const Text('Manage Assistants'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ManageAssistantsScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: buttonStyle,
                    child: const Text('View Facilities'),
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => FacilityScreen()),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                ],

                ElevatedButton(
                  style: buttonStyle,
                  child: const Text('Change Password'),
                  onPressed: () {
                    final email = FirebaseAuth.instance.currentUser?.email;
                    if (email != null) _showChangePasswordDialog(email);
                  },
                ),
                if (Provider.of<UserRoleProvider>(context).isAdmin) ...[
                  const SizedBox(height: 12),
                  ElevatedButton(
                    style: buttonStyle,
                    child: const Text('Activity Log'),
                    onPressed: () => showActivityLog(context),
                  ),
                ],
                const SizedBox(height: 12),
                Divider(thickness: 1.2, color: Colors.grey.shade400),
                const SizedBox(height: 80),
              ],
            ),

            // Close X button
            Positioned(
              top: 16,
              right: 16,
              child: Tooltip(
                message: 'Close',
                child: IconButton(
                  icon: const Icon(Icons.close, size: 28, color: Colors.black54),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
            ),

            // Logout button
            Positioned(
              bottom: 16,
              right: 16,
              child: Tooltip(
                message: 'Logout',
                child: InkWell(
                  borderRadius: BorderRadius.circular(30),
                  hoverColor: Colors.teal.shade700,
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: Colors.white,
                        title: Text('Logout', style: TextStyle(color: primaryDeepGreen)),
                        content: const Text('Are you sure you want to logout?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(ctx).pop(),
                            child: Text('Cancel', style: TextStyle(color: primaryDeepGreen)),
                          ),
                          TextButton(
                            onPressed: () async {
                              Navigator.of(ctx).pop();
                              await forceLogoutAndShowLogin();
                            },
                            child: const Text('Logout', style: TextStyle(color: Colors.red)),
                          ),
                        ],
                      ),
                    );
                  },
                  child: Ink(
                    decoration: const ShapeDecoration(
                      color: Color(0xFF2F5D62),
                      shape: CircleBorder(),
                    ),
                    child: const Padding(
                      padding: EdgeInsets.all(8.0),
                      child: Icon(Icons.power_settings_new, size: 16, color: Colors.white),
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

  // --------------------- DRAWER ITEM ---------------------
  Widget _drawerItem(IconData icon, String title, Widget page) {
    return ListTile(
      leading: Icon(icon, color: offWhite),
      title: Text(title, style: TextStyle(color: offWhite)),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => page)),
    );
  }

}
