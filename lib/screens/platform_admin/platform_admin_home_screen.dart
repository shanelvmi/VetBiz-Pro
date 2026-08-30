import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/force_logout.dart';
import '../../utils/activity_signal.dart';
import 'overview_tab.dart';
import 'facilities_directory_tab.dart';
import 'subscription_requests_tab.dart';
import 'announcements_tab.dart';
import 'platform_admins_tab.dart';
import 'users_tab.dart';
import 'platform_settings_screen.dart';

/// One navigation entry - a simple data record rather than each item
/// being hand-built inline. Adding a new section (or, later, a nested
/// sub-menu under one) means adding one entry here, not touching the
/// sidebar/drawer/header layout code at all.
class _AdminNavItem {
  final IconData icon;
  final String label;
  final Widget page;
  const _AdminNavItem({required this.icon, required this.label, required this.page});
}

/// Home shell for the whole Platform Admin panel (you, the SaaS
/// operator) - a single access check here, then six sections covering
/// everything a platform operator needs day to day: a snapshot of the
/// business, every facility at a glance, user accounts, pending payment
/// reviews, broadcasting announcements, and managing who else has this
/// access.
///
/// Desktop/laptop: a collapsible left sidebar (expanded icons+labels,
/// or collapsed icons-only with hover tooltips), grouped into "Main
/// Menu" (the six sections above) and "Others" (Settings, Logout), with
/// a clean top header reserved for the panel title and account
/// identity. Mobile/tablet: the sidebar disappears entirely in favour
/// of a hamburger-triggered drawer overlay, so nothing about the
/// content area's width is ever spent on a persistent nav panel that
/// has no room to spare.
///
/// This is the most sensitive area of the whole app - standing access
/// to every facility's data, financial records, and account controls.
/// Signs out automatically after a period with no real interaction at
/// all, rather than staying open indefinitely on an unattended,
/// unlocked device.
class PlatformAdminHomeScreen extends StatefulWidget {
  const PlatformAdminHomeScreen({super.key});

  @override
  State<PlatformAdminHomeScreen> createState() => _PlatformAdminHomeScreenState();
}

class _PlatformAdminHomeScreenState extends State<PlatformAdminHomeScreen> {
  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);
  static const Color offWhite = Color(0xFFFDFDF9);

  // Same breakpoint the main Dashboard already uses for this exact
  // sidebar-vs-drawer decision - kept consistent with the rest of the
  // app rather than introducing a second, different threshold.
  static const double _wideBreakpoint = 1024;

  static const List<_AdminNavItem> _navItems = [
    _AdminNavItem(icon: Icons.dashboard_outlined, label: 'Overview', page: OverviewTab()),
    _AdminNavItem(icon: Icons.storefront_outlined, label: 'Facilities', page: FacilitiesDirectoryTab()),
    _AdminNavItem(icon: Icons.people_outline, label: 'Users', page: UsersTab()),
    _AdminNavItem(icon: Icons.receipt_long_outlined, label: 'Requests', page: SubscriptionRequestsTab()),
    _AdminNavItem(icon: Icons.campaign_outlined, label: 'Branding', page: AnnouncementsTab()),
    _AdminNavItem(icon: Icons.admin_panel_settings_outlined, label: 'Admins', page: PlatformAdminsTab()),
  ];

  int _selectedIndex = 0;
  bool _isSidebarCollapsed = false;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Chosen for a sensitive admin panel specifically, not the rest of
  // the app - a regular Admin/Assistant working inside their own
  // facility is a different risk profile from standing access to
  // every facility on the platform.
  static const Duration _inactivityTimeout = Duration(minutes: 15);
  static const Duration _warningBefore = Duration(minutes: 1);

  Timer? _warningTimer;
  Timer? _logoutTimer;
  bool _warningShown = false;
  StreamSubscription<void>? _activitySubscription;

  @override
  void initState() {
    super.initState();
    _resetInactivityTimers();
    // Subscribed only while this screen is actually mounted, so the
    // timers (and the cost of tracking them) only exist while someone
    // is genuinely inside Platform Admin, not for the rest of the app.
    _activitySubscription = globalActivitySignal.stream.listen((_) => _resetInactivityTimers());
    _loadSidebarPreference();
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
    _activitySubscription?.cancel();
    super.dispose();
  }

  Future<void> _loadSidebarPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() => _isSidebarCollapsed = prefs.getBool('platform_admin_sidebar_collapsed') ?? false);
    }
  }

  Future<void> _toggleSidebarCollapsed() async {
    final newValue = !_isSidebarCollapsed;
    setState(() => _isSidebarCollapsed = newValue);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('platform_admin_sidebar_collapsed', newValue);
  }

  // Restarts both timers from zero - called on any real interaction
  // (a tap/click, or a scroll), and again when someone explicitly
  // chooses to stay signed in from the warning dialog.
  void _resetInactivityTimers() {
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
    _warningShown = false;

    _warningTimer = Timer(_inactivityTimeout - _warningBefore, _showInactivityWarning);
    _logoutTimer = Timer(_inactivityTimeout, _handleInactivityLogout);
  }

  void _showInactivityWarning() {
    if (!mounted || _warningShown) return;
    _warningShown = true;

    showDialog<void>(
      context: context,
      // Deliberately not dismissable by tapping outside - a barrier
      // tap would reset the timer just like any other activity, but
      // requiring the explicit button below means someone actually
      // acknowledges the warning, rather than dismissing it by
      // accident and being left unsure whether they're still about to
      // be signed out.
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Still there?'),
        content: SizedBox(
          width: MediaQuery.of(context).size.width > 700 ? 360 : MediaQuery.of(context).size.width * 0.85,
          child: const Text(
            'For security, Platform Admin signs out automatically after a period of '
            'inactivity. You\'ll be signed out in about a minute unless you stay active.',
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _resetInactivityTimers();
            },
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return warmAmber;
                return primaryColor;
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: const Text('Stay Signed In'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleInactivityLogout() async {
    if (!mounted) return;
    // forceLogoutAndShowLogin() itself pops every route back to the
    // app's base route - including the warning dialog above, if it's
    // still showing, since showDialog defaults to the same root
    // navigator that pop targets. No separate dismiss needed here.
    await forceLogoutAndShowLogin(
      message: 'Signed out of Platform Admin after a period of inactivity.',
    );
  }

  Future<void> _confirmLogout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Logout?'),
        content: const Text('You\'ll need to sign in again to access the Platform Admin panel.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: TextButton.styleFrom(foregroundColor: primaryColor),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: ButtonStyle(
              backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                if (states.contains(WidgetState.hovered)) return warmAmber;
                return primaryColor;
              }),
              foregroundColor: WidgetStateProperty.all(Colors.white),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );
    if (confirmed == true) forceLogoutAndShowLogin();
  }

  void _selectIndex(int index) {
    setState(() => _selectedIndex = index);
  }

  // Settings isn't itself one of _navItems, so its name has to be
  // resolved separately from the six Main Menu labels.
  String get _currentPageTitle {
    if (_selectedIndex < _navItems.length) return _navItems[_selectedIndex].label;
    return 'Settings';
  }

  // Wraps a page in its own independent navigation stack - any
  // Navigator.push() called from within that page (a user's detail
  // screen, a facility's detail screen, etc.) automatically targets
  // this nested Navigator rather than the app's root one, since
  // Navigator.push(context, ...) always uses whichever Navigator is
  // nearest in the widget tree. That keeps the sidebar, header, and
  // page title fully visible underneath the pushed screen instead of
  // it replacing the whole layout - no changes needed to any
  // individual screen's own navigation code to get this.
  Widget _wrapInNestedNavigator(Widget page) {
    return Navigator(
      onGenerateRoute: (settings) => MaterialPageRoute(builder: (_) => page),
    );
  }

  // Fixed panel title rather than the current section's name - the
  // sidebar's own highlighted tile already shows which section is
  // active, so repeating it here would just be the same information
  // twice.
  Widget _buildHeader({required bool isWide}) {
    final currentUser = FirebaseAuth.instance.currentUser;

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          if (!isWide)
            IconButton(
              icon: const Icon(Icons.menu),
              color: primaryColor,
              tooltip: 'Menu',
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
          const Expanded(
            child: Center(
              child: Text(
                'Platform Admin',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: primaryColor),
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            tooltip: 'Notifications (coming soon)',
            color: Colors.grey[700],
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Notifications are coming soon.')),
              );
            },
          ),
          const SizedBox(width: 8),
          if (currentUser != null)
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance.collection('users').doc(currentUser.uid).snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data();
                final name = (data?['fullName'] as String?) ?? currentUser.email ?? 'Admin';
                final avatarUrl = data?['avatarUrl'] as String?;

                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: primaryColor.withValues(alpha: 0.1),
                      backgroundImage: (avatarUrl != null && avatarUrl.isNotEmpty)
                          ? NetworkImage(avatarUrl)
                          : null,
                      child: (avatarUrl == null || avatarUrl.isEmpty)
                          ? Icon(Icons.person, size: 18, color: primaryColor)
                          : null,
                    ),
                    if (isWide) ...[
                      const SizedBox(width: 8),
                      ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 140),
                        child: Text(
                          name,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: primaryColor),
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildBrandMark() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: _isSidebarCollapsed
          ? const Icon(Icons.storefront, color: Colors.white, size: 26)
          : const Text(
              'VetBiz Pro',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, letterSpacing: 0.3),
            ),
    );
  }

  // A small, muted section label above each group of tiles, sitting
  // noticeably shallower than the tiles beneath it - hidden entirely
  // when collapsed, since there's no room for text at that width and
  // the icons alone are already grouped visually by the gap between
  // them.
  Widget _buildGroupLabel(String label, {required bool collapsed}) {
    if (collapsed) return const SizedBox(height: 12);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 8),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 11,
          fontWeight: FontWeight.bold,
          letterSpacing: 0.8,
        ),
      ),
    );
  }

  // A single tile shape, shared by every entry regardless of whether
  // it selects one of the six main sections, or triggers an action
  // (Settings, Logout) - only which of those two happens on tap
  // differs, not how the tile itself looks or highlights. The tile's
  // own margin (not just its internal padding) sits deeper than the
  // group label above it - the visible highlighted block itself must
  // start further right than the label, not just the icon inside it,
  // or the two contradict each other regardless of how deep the icon
  // alone is pushed.
  Widget _buildTile({
    required IconData icon,
    required String label,
    required bool selected,
    required bool collapsed,
    required VoidCallback onTap,
  }) {
    final tile = InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        margin: EdgeInsets.fromLTRB(collapsed ? 8 : 20, 3, 6, 3),
        padding: EdgeInsets.only(left: collapsed ? 0 : 6, right: collapsed ? 0 : 4, top: 12, bottom: 12),
        decoration: BoxDecoration(
          color: selected ? warmAmber.withValues(alpha: 0.18) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border(left: BorderSide(color: selected ? warmAmber : Colors.transparent, width: 3)),
        ),
        child: Row(
          mainAxisAlignment: collapsed ? MainAxisAlignment.center : MainAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? warmAmber : Colors.white70, size: 20),
            if (!collapsed) ...[
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: selected ? Colors.white : Colors.white70,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );

    // Icons-only mode loses the text label entirely - a tooltip is
    // what keeps every item identifiable without it, exactly as
    // specified.
    if (collapsed) {
      return Tooltip(message: label, waitDuration: const Duration(milliseconds: 400), child: tile);
    }
    return tile;
  }

  // The full nav column - "Main Menu" (the six sections) then "Others"
  // (Settings, Logout) - shared as-is between the persistent sidebar
  // and the mobile drawer, since only the surrounding chrome (collapse
  // toggle, tap-closes-drawer) differs between the two, not the
  // groups/tiles themselves.
  Widget _buildNavColumn({required bool collapsed, VoidCallback? onNavigate}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildGroupLabel('Main Menu', collapsed: collapsed),
        ..._navItems.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          return _buildTile(
            icon: item.icon,
            label: item.label,
            selected: index == _selectedIndex,
            collapsed: collapsed,
            onTap: () {
              _selectIndex(index);
              onNavigate?.call();
            },
          );
        }),
        const Divider(color: Colors.white24, height: 1),
        _buildGroupLabel('Others', collapsed: collapsed),
        _buildTile(
          icon: Icons.settings_outlined,
          label: 'Settings',
          selected: _selectedIndex == _navItems.length,
          collapsed: collapsed,
          onTap: () {
            _selectIndex(_navItems.length);
            onNavigate?.call();
          },
        ),
      ],
    );
  }

  // Pinned at the very bottom, deliberately separate from the
  // scrollable Main Menu/Others group above it - not sitting
  // immediately next to Settings, so it can't be mistaken for part of
  // that same group or tapped by accident right after it.
  Widget _buildLogoutTile({required bool collapsed, VoidCallback? onNavigate}) {
    return _buildTile(
      icon: Icons.logout,
      label: 'Logout',
      selected: false,
      collapsed: collapsed,
      onTap: () {
        onNavigate?.call();
        _confirmLogout();
      },
    );
  }

  // Persistent, expanded-or-collapsed side panel for desktop/laptop
  // widths - a fluid width transition between the two states, rather
  // than an abrupt jump.
  Widget _buildSidebar() {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeInOut,
      width: _isSidebarCollapsed ? 72 : 240,
      color: primaryColor,
      child: Column(
        children: [
          _buildBrandMark(),
          const Divider(color: Colors.white24, height: 1),
          Expanded(
            child: SingleChildScrollView(
              child: _buildNavColumn(collapsed: _isSidebarCollapsed),
            ),
          ),
          const Divider(color: Colors.white24, height: 1),
          _buildLogoutTile(collapsed: _isSidebarCollapsed),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.all(8),
            child: IconButton(
              icon: Icon(
                _isSidebarCollapsed ? Icons.chevron_right : Icons.chevron_left,
                color: Colors.white70,
              ),
              tooltip: _isSidebarCollapsed ? 'Expand menu' : 'Collapse menu',
              onPressed: _toggleSidebarCollapsed,
            ),
          ),
        ],
      ),
    );
  }

  // Slide-out overlay for mobile/tablet - same nav column, always in
  // full-label form since there's no persistent width to economise on
  // here at all.
  Widget _buildMobileDrawer() {
    return Drawer(
      backgroundColor: primaryColor,
      child: SafeArea(
        child: Column(
          children: [
            _buildBrandMark(),
            const Divider(color: Colors.white24, height: 1),
            Expanded(
              child: SingleChildScrollView(
                child: _buildNavColumn(
                  collapsed: false,
                  onNavigate: () => Navigator.pop(context),
                ),
              ),
            ),
            const Divider(color: Colors.white24, height: 1),
            _buildLogoutTile(collapsed: false, onNavigate: () => Navigator.pop(context)),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // No access re-check here, deliberately - the only way to ever reach
  // this screen is through main.dart's login flow, which has already
  // confirmed Platform Admin access before ever returning this widget.
  // An earlier version re-verified it again here via its own
  // FutureBuilder, calling the check directly inline as `future:` -
  // which recreated it (and restarted the whole check) on every single
  // rebuild, including the extra ones triggered by the login screen's
  // fade transition. That was very likely the actual, final cause of
  // "logs in fine, but the second time just spins forever."
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= _wideBreakpoint;

        // Every page kept alive simultaneously (only one visible at a
        // time) rather than rebuilt from scratch on every switch - the
        // same behaviour the previous TabBarView-based layout already
        // had, so switching sections and back doesn't lose scroll
        // position or already-loaded data.
        final content = Column(
          children: [
            _buildHeader(isWide: isWide),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _currentPageTitle,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: primaryColor),
                ),
              ),
            ),
            Expanded(
              child: Container(
                color: offWhite,
                child: IndexedStack(
                  index: _selectedIndex,
                  children: [
                    ..._navItems.map((item) => _wrapInNestedNavigator(item.page)),
                    _wrapInNestedNavigator(const PlatformSettingsScreen()),
                  ],
                ),
              ),
            ),
          ],
        );

        if (isWide) {
          return Scaffold(
            body: Row(
              children: [
                _buildSidebar(),
                Expanded(child: content),
              ],
            ),
          );
        }

        return Scaffold(
          key: _scaffoldKey,
          drawer: _buildMobileDrawer(),
          body: content,
        );
      },
    );
  }
}
