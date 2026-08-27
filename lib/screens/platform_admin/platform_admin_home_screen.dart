import 'dart:async';
import 'package:flutter/material.dart';

import '../../utils/force_logout.dart';
import '../../utils/activity_signal.dart';
import 'overview_tab.dart';
import 'facilities_directory_tab.dart';
import 'subscription_requests_tab.dart';
import 'announcements_tab.dart';
import 'platform_admins_tab.dart';
import 'users_tab.dart';
import 'platform_settings_screen.dart';

/// Home shell for the whole Platform Admin panel (you, the SaaS
/// operator) - a single access check here, then five tabs covering
/// everything a platform operator needs day to day: a snapshot of the
/// business, every facility at a glance, pending payment reviews,
/// broadcasting announcements, and managing who else has this access.
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

  static const List<Tab> _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Facilities'),
    Tab(text: 'Users'),
    Tab(text: 'Requests'),
    Tab(text: 'Branding'),
    Tab(text: 'Admins'),
  ];

  static const List<Widget> _tabViews = [
    OverviewTab(),
    FacilitiesDirectoryTab(),
    UsersTab(),
    SubscriptionRequestsTab(),
    AnnouncementsTab(),
    PlatformAdminsTab(),
  ];

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
  }

  @override
  void dispose() {
    _warningTimer?.cancel();
    _logoutTimer?.cancel();
    _activitySubscription?.cancel();
    super.dispose();
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
    return DefaultTabController(
          length: _tabs.length,
          child: Scaffold(
            appBar: AppBar(
              title: const Text('Platform Admin'),
              centerTitle: true,
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              actions: [
                IconButton(
                  icon: const Icon(Icons.settings_outlined),
                  tooltip: 'Platform Settings',
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return Colors.white;
                    }),
                  ),
                  onPressed: () => showPlatformSettingsScreen(context),
                ),
                IconButton(
                  icon: const Icon(Icons.logout),
                  tooltip: 'Logout',
                  style: ButtonStyle(
                    foregroundColor: WidgetStateProperty.resolveWith<Color>((states) {
                      if (states.contains(WidgetState.hovered)) return warmAmber;
                      return Colors.white;
                    }),
                  ),
                  onPressed: () async {
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
                  },
                ),
              ],
              bottom: PreferredSize(
                // Extra height accommodates the centered/wrapped layout
                // on narrower widths without clipping the tab labels.
                preferredSize: const Size.fromHeight(48),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    // Wide screens (desktop/tablet): tabs sit evenly
                    // spaced and centered, like most SaaS dashboards.
                    // Narrow phones: falls back to a scrollable row so
                    // five labels never get cramped or clipped.
                    final isWide = constraints.maxWidth >= 700;

                    final tabBar = TabBar(
                      isScrollable: !isWide,
                      indicatorColor: warmAmber,
                      indicatorWeight: 3,
                      labelColor: Colors.white,
                      unselectedLabelColor: Colors.white70,
                      tabs: _tabs,
                    );

                    if (!isWide) return tabBar;

                    return Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 700),
                        child: tabBar,
                      ),
                    );
                  },
                ),
              ),
            ),
            body: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1000),
                child: TabBarView(children: _tabViews),
              ),
            ),
          ),
        );
  }
}
