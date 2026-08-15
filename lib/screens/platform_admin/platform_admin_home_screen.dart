import 'package:flutter/material.dart';

import '../../utils/force_logout.dart';
import 'overview_tab.dart';
import 'facilities_directory_tab.dart';
import 'subscription_requests_tab.dart';
import 'announcements_tab.dart';
import 'platform_admins_tab.dart';
import 'users_tab.dart';

/// Home shell for the whole Platform Admin panel (you, the SaaS
/// operator) - a single access check here, then five tabs covering
/// everything a platform operator needs day to day: a snapshot of the
/// business, every facility at a glance, pending payment reviews,
/// broadcasting announcements, and managing who else has this access.
class PlatformAdminHomeScreen extends StatelessWidget {
  const PlatformAdminHomeScreen({super.key});

  static const Color primaryColor = Color(0xFF2F5D62);
  static const Color warmAmber = Color(0xFFFFB200);

  static const List<Tab> _tabs = [
    Tab(text: 'Overview'),
    Tab(text: 'Facilities'),
    Tab(text: 'Users'),
    Tab(text: 'Requests'),
    Tab(text: 'Announcements'),
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
