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
import '../../services/dashboard_summary_service.dart';

import '../../widgets/summary_card.dart';

import '../products/products_screen.dart';
import '../clients/clients_screen.dart';
import '../services/services_screen.dart';
import '../sales/sales_screen.dart';
import '../transactions/transactions_screen.dart';
import '../facilities/facility_screen.dart';
import '../settings/settings_screen.dart';
import '../activity/activity_log_screen.dart';
import '../debtors/debtors_screen.dart';
import '../payments/payments_screen.dart';
import '../../providers/subscription_provider.dart';
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
    final row = Row(
      mainAxisAlignment: widget.isCollapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
      children: [
        Icon(widget.icon, color: offWhite),
        if (!widget.isCollapsed) ...[
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              widget.title,
              style: TextStyle(
                color: offWhite,
                fontWeight: FontWeight.w500,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
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
  const _BlinkingDot();

  @override
  State<_BlinkingDot> createState() => _BlinkingDotState();
}

class _BlinkingDotState extends State<_BlinkingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
      ),
      child: Container(
        width: 9,
        height: 9,
        decoration: const BoxDecoration(color: Colors.redAccent, shape: BoxShape.circle),
      ),
    );
  }
}

/// Wraps the profile avatar with hover feedback (a ring, matching the
/// amber-on-hover convention used throughout the app) - a background
/// fill wouldn't read well on a circular avatar the way it does on a
/// button, so this uses a border instead.
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
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
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

class _DashboardScreenState extends State<DashboardScreen> {
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

  @override
  void dispose() {
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
    final facilityType = selectedFacility['type'] as String? ?? '';
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

    final formatter = NumberFormat.decimalPattern();

    return LayoutBuilder(
      builder: (context, constraints) {
        bool isLargeScreen = constraints.maxWidth >= 1024;

        return Scaffold(
          backgroundColor: offWhite,
          appBar: AppBar(
            backgroundColor: primaryDeepGreen,
            elevation: 4,
            centerTitle: true,
            iconTheme: IconThemeData(color: offWhite),
            leadingWidth: isLargeScreen ? 280 : null,
            leading: isLargeScreen
                ? Row(
                    children: [
                      const SizedBox(width: 8),
                      _buildAlertsBell(context),
                      Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: StreamBuilder(
                      stream: Stream.periodic(const Duration(seconds: 1)),
                      builder: (context, snapshot) {
                        final now = DateTime.now();
                        final formattedDate =
                            DateFormat('EEE, MMM d, yyyy').format(now);
                        final formattedTime =
                            DateFormat('HH:mm:ss').format(now);

                        return Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                formattedTime,
                                style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: offWhite),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                formattedDate,
                                style: TextStyle(fontSize: 12, color: offWhite),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                      const Spacer(),
                      IconButton(
                        icon: Icon(
                          _isDrawerCollapsed ? Icons.menu_open : Icons.menu,
                          color: offWhite,
                          size: 20,
                        ),
                        tooltip: _isDrawerCollapsed ? 'Expand menu' : 'Collapse menu',
                        onPressed: _toggleDrawerCollapsed,
                      ),
                    ],
                  )
                : null,
            title: StreamBuilder<DocumentSnapshot>(
              stream: userDoc.snapshots(),
              builder: (context, snapshot) {
                final rawData = snapshot.data?.data();
                final Map<String, dynamic> data = (rawData != null && rawData is Map)
                    ? Map<String, dynamic>.from(rawData)
                    : {};
                final fullName = data['fullName'] ?? '';

                return Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      facilityType.isNotEmpty && facilityType != 'Other'
                          ? '$facilityName $facilityType Dashboard'
                          : '$facilityName Dashboard',
                      style: TextStyle(color: offWhite),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${greetingTime()}, $fullName',
                      style: TextStyle(fontSize: 10, color: offWhite),
                    ),
                  ],
                );
              },
            ),
            actions: [
              if (!isLargeScreen) _buildAlertsBell(context),
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

                        return CircleAvatar(
                          radius: 16,
                          backgroundImage: (_profileBytes != null)
                              ? MemoryImage(_profileBytes!)
                              : (avatarUrl != null && avatarUrl.isNotEmpty)
                                  ? NetworkImage(avatarUrl)
                                  : null,
                          child: (_profileBytes == null &&
                                  (avatarUrl == null || avatarUrl.isEmpty))
                              ? const Icon(Icons.person)
                              : null,
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
                    Row(
                      children: [
                        if (isLargeScreen) _buildDrawerContent(),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              children: [
                                if (isLargeScreen)
                                  Row(
                                    children: [
                                      Expanded(
                                    child: Center(
                                      child: Wrap(
                                        spacing: 8,
                                        children: ['Today', 'This Week', 'This Month', 'This Year']
                                            .map((filter) => ChoiceChip(
                                                  label: Text(filter),
                                                  selected: selectedFilter == filter,
                                                  onSelected: (val) {
                                                    setState(() {
                                                      selectedFilter = filter;
                                                    });
                                                  },
                                                  selectedColor: warmAmber,
                                                ))
                                            .toList(),
                                      ),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (_) => const InsightsScreen()),
                                      );
                                    },
                                    icon: Icon(Icons.insights, color: primaryDeepGreen),
                                    label: Text('Insights', style: TextStyle(color: primaryDeepGreen)),
                                    style: OutlinedButton.styleFrom(side: BorderSide(color: primaryDeepGreen)),
                                  ),
                                ],
                              )
                            else ...[
                              Wrap(
                                spacing: 8,
                                children: ['Today', 'This Week', 'This Month', 'This Year']
                                    .map((filter) => ChoiceChip(
                                          label: Text(filter),
                                          selected: selectedFilter == filter,
                                          onSelected: (val) {
                                            setState(() {
                                              selectedFilter = filter;
                                            });
                                          },
                                          selectedColor: warmAmber,
                                        ))
                                    .toList(),
                              ),
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: OutlinedButton.icon(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(builder: (_) => const InsightsScreen()),
                                    );
                                  },
                                  icon: Icon(Icons.insights, color: primaryDeepGreen),
                                  label: Text('Insights', style: TextStyle(color: primaryDeepGreen)),
                                  style: OutlinedButton.styleFrom(side: BorderSide(color: primaryDeepGreen)),
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Expanded(
                              child: LayoutBuilder(
                                builder: (context, gridConstraints) {
                                  final gridWidth = gridConstraints.maxWidth;
                                  // More columns on wide screens; a taller
                                  // (lower) aspect ratio on narrow ones so
                                  // card content has room to breathe -
                                  // SummaryCard itself also self-scales,
                                  // this just picks a sensible starting
                                  // shape per screen size.
                                  final crossAxisCount = gridWidth > 1200
                                      ? 4
                                      : gridWidth > 700
                                          ? 3
                                          : 2;
                                  final childAspectRatio = gridWidth > 1200
                                      ? 1.5
                                      : gridWidth > 400
                                          ? 1.3
                                          : 1.05;

                                  return GridView.count(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: childAspectRatio,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                    children: [
                                      SummaryCard(
                                        title: 'Total Product Value',
                                        value: 'Tsh ${formatter.format(productProvider.totalProductValue)}',
                                        icon: Icons.inventory,
                                        color: primaryDeepGreen,
                                        shadow: true,
                                        subtitle: 'as of now',
                                      ),
                                      SummaryCard(
                                        title: 'Total Sales ($selectedFilter)',
                                        value: 'Tsh ${formatter.format(_periodTotals.totalSales)}',
                                        icon: Icons.shopping_cart,
                                        color: warmAmber,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                      ),
                                      SummaryCard(
                                        title: 'Total Earnings ($selectedFilter)',
                                        value: 'Tsh ${formatter.format(_periodTotals.totalEarnings)}',
                                        icon: Icons.attach_money,
                                        color: primaryDeepGreen,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
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
                                      ),
                                      SummaryCard(
                                        title: 'Total Expenses ($selectedFilter)',
                                        value: 'Tsh ${formatter.format(_periodTotals.totalExpenses)}',
                                        icon: Icons.trending_down,
                                        color: Colors.red,
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                      ),
                                      SummaryCard(
                                        title: 'Outstanding Payment',
                                        value: 'Tsh ${formatter.format(debtProvider.totalOutstanding())}',
                                        icon: Icons.account_balance_wallet,
                                        color: warmAmber,
                                        shadow: true,
                                        subtitle: 'as of now',
                                      ),
                                      SummaryCard(
                                        title: 'Total Clients',
                                        value: '${clientProvider.clients.length}',
                                        icon: Icons.people,
                                        color: warmAmber,
                                        shadow: true,
                                        subtitle: 'as of now',
                                      ),
                                      SummaryCard(
                                        title: 'Completed Services ($selectedFilter)',
                                        value: '${_periodTotals.completedServicesCount}',
                                        icon: Icons.design_services,
                                        color: const Color(0xFF3D5A80),
                                        shadow: true,
                                        isLoading: _isPeriodLoading,
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
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
          floatingActionButton: _buildFABs(),
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

    final needsAttention = sub.status != SubscriptionStatus.trial &&
        !(sub.status == SubscriptionStatus.active &&
            (sub.daysRemaining == null || sub.daysRemaining! > 7));

    final isSnoozed = _subscriptionSnoozedUntil != null &&
        DateTime.now().isBefore(_subscriptionSnoozedUntil!);
    final shouldShow = needsAttention && !isSnoozed && _subscriptionPillDelayPassed;

    final isLocked = sub.status == SubscriptionStatus.locked;
    final isGrace = sub.status == SubscriptionStatus.grace;
    // The accent - carried by the icon, the text, and a thin border -
    // rather than a full background fill. Same deepened, burnt-amber
    // reasoning as before: the brand's own warmAmber is too close to
    // yellow to read cleanly as an accent on a cream background.
    const Color deepAmber = Color(0xFFC77800);
    final accent = isLocked ? Colors.redAccent : deepAmber;
    const Color cream = Color(0xFFFFF6E7);

    // Full sentence now that this sits in its own row above the filter
    // chips, rather than the shortened version needed when it was
    // squeezed inline next to Insights.
    String message;
    if (isLocked) {
      message = 'Your subscription has expired. The app is in read-only mode.';
    } else if (isGrace) {
      message = 'Your subscription has expired. You have a few days of grace before read-only mode begins.';
    } else {
      message = 'Your subscription expires in ${sub.daysRemaining} day${sub.daysRemaining == 1 ? '' : 's'}.';
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
                  Icon(isLocked ? Icons.lock_outline : Icons.warning_amber_rounded, color: accent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    message,
                    style: const TextStyle(color: Colors.black87, fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                  if (isAdmin) ...[
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const SubscriptionScreen()),
                        );
                      },
                      child: Text(
                        'Renew',
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
  Widget _buildAlertsBell(BuildContext context) {
    final products = Provider.of<ProductProvider>(context).products;
    final hasStockAlerts = StockAlertsScreen.hasAnyAlert(products);

    final sub = Provider.of<SubscriptionProvider>(context);
    // Same thresholds as the pill/Notifications screen, so all three
    // never disagree about whether the subscription needs attention.
    final subscriptionNeedsAttention = sub.status != SubscriptionStatus.trial &&
        !(sub.status == SubscriptionStatus.active &&
            (sub.daysRemaining == null || sub.daysRemaining! > 7));

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

        return Stack(
          clipBehavior: Clip.none,
          children: [
            IconButton(
              icon: const Icon(Icons.notifications_outlined),
              tooltip: 'Notifications',
              onPressed: () async {
                await Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const StockAlertsScreen()),
                );
                // Notifications marks itself "viewed" on open - re-check
                // here so the blink stops immediately on return, rather
                // than waiting for some other reason to rebuild.
                _refreshNotificationsViewedState();
              },
            ),
            if (hasNew)
              const Positioned(
                right: 8,
                top: 8,
                child: _BlinkingDot(),
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
  // Display only now - logo management lives in Settings > Business
  // Profile, so this no longer needs to be tappable, and correctly
  // reflects whatever's actually saved (via FacilityProvider's live
  // listener) rather than a locally-picked image that was never wired
  // to that update path.
  Widget logoSection = Container(
    width: double.infinity,
    padding: const EdgeInsets.only(top: 18, bottom: 12),
    alignment: Alignment.center,
    child: CircleAvatar(
      radius: effectivelyCollapsed ? 18 : 30,
      backgroundColor: offWhite,
      backgroundImage: (selectedFacility != null && selectedFacility['logoUrl'] != null)
          ? NetworkImage(selectedFacility['logoUrl'] as String)
          : const AssetImage('assets/vetbiz_pro_logo.png') as ImageProvider,
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
        title: 'Services',
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

  // ---------- FINAL LAYOUT ----------
  Widget content = Column(
    children: [
      logoSection,
      Divider(thickness: 1.2, color: Colors.white54),
      items,
      Divider(thickness: 1.2, color: Colors.white54),
      settings,
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
          child: isSmallScreen
              ? SingleChildScrollView(child: content)
              : content,
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
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: offWhite,
                          backgroundImage: _profileBytes != null
                              ? MemoryImage(_profileBytes!)
                              : (avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null),
                          child: (_profileBytes == null &&
                                  (avatarUrl == null || avatarUrl.isEmpty))
                              ? const Icon(Icons.person, size: 50, color: Colors.grey)
                              : null,
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
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => ActivityLogScreen()),
                      );
                    },
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

  // --------------------- FLOATING ACTION BUTTONS ---------------------
  Widget _buildFABs() {
  final isLargeScreen = MediaQuery.of(context).size.width >= 1024;

  if (isLargeScreen) {
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      HoverFab(
        heroTag: 'add_sale',
        icon: Icons.add_shopping_cart,
        label: 'Add Sale',
        color: warmAmber,
        hoverColor: const Color(0xFFFFC400),
        onPressed: () => navigateOrShowLockedDialog(context, AddSaleScreen()),
      ),
      const SizedBox(width: 12),
      HoverFab(
        heroTag: 'add_product',
        icon: Icons.add_box,
        label: 'Add Product',
        color: primaryDeepGreen,
        hoverColor: const Color(0xFF3B6B6E),
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditProductScreen()),
        ),
      ),
      const SizedBox(width: 12),
      HoverFab(
        heroTag: 'add_service',
        icon: Icons.design_services,
        label: 'Add Service',
        color: const Color(0xFF3D5A80),
        hoverColor: const Color(0xFF4A6B94),
        onPressed: () => navigateOrShowLockedDialog(context, AddEditServiceScreen()),
      ),
    ],
  );
 }

  // Mobile → no hover
  return SpeedDial(
    icon: Icons.add,
    activeIcon: Icons.close,
    backgroundColor: primaryDeepGreen,
    foregroundColor: offWhite,
    overlayColor: Colors.black,
    overlayOpacity: 0.4,
    children: [
      SpeedDialChild(
        backgroundColor: warmAmber,
        child: const Icon(Icons.add_shopping_cart, color: Colors.white),
        label: 'Add Sale',
        onTap: () => navigateOrShowLockedDialog(context, AddSaleScreen()),
      ),
      SpeedDialChild(
        backgroundColor: primaryDeepGreen,
        child: const Icon(Icons.add_box, color: Colors.white),
        label: 'Add Product',
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => AddEditProductScreen()),
        ),
      ),
      SpeedDialChild(
        backgroundColor: const Color(0xFF3D5A80),
        child: const Icon(Icons.design_services, color: Colors.white),
        label: 'Add Service',
        onTap: () => navigateOrShowLockedDialog(context, AddEditServiceScreen()),
      ),
    ],
  );
}

}
