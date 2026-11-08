// UI3: the profile menu at tablet and computer widths (the end drawer the
// top bar's ProfileMenuButton opens; the phone's avatar opens the same one).
// Recorded from the code before UI3 (test/fixtures/ph5a_wide_fingerprints.json,
// the ui3-profile-drawer- names); UI3 changes only its Facility row, so these
// are re-recorded once with that change and must otherwise stay put.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/widgets/profile/profile_drawer.dart';

import 'helpers/screen_size_matrix.dart';
import 'helpers/tree_fingerprint.dart';

const _sizes = [Size(768, 1024), Size(1024, 768), Size(1200, 800)];

/// The rows the dashboard gives the drawer (dashboard_screen.dart
/// _buildEndDrawerContent): admins see Team Members, View Facilities and
/// Activity log too.
List<ProfileDrawerAction> _actions({required bool admin}) => [
      ProfileDrawerAction(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () {}),
      if (admin) ...[
        ProfileDrawerAction(icon: Icons.group_outlined, label: 'Team Members', onTap: () {}),
        ProfileDrawerAction(icon: Icons.store_outlined, label: 'View Facilities', onTap: () {}),
      ],
      ProfileDrawerAction(icon: Icons.lock_outline, label: 'Change Password', onTap: () {}),
      if (admin) ProfileDrawerAction(icon: Icons.history, label: 'Activity Log', onTap: () {}),
      ProfileDrawerAction(icon: Icons.power_settings_new, label: 'Sign out', onTap: () {}, destructive: true),
    ];

/// A page with the drawer open at its end, as the dashboard opens it.
Widget ui3DrawerPage({required bool admin, String facility = 'Mwanzo Agrovet', Widget? content}) {
  final key = GlobalKey<ScaffoldState>();
  WidgetsBinding.instance.addPostFrameCallback((_) => key.currentState?.openEndDrawer());
  return Scaffold(
    key: key,
    body: const SizedBox.expand(),
    endDrawer: Drawer(
      child: content ??
          ProfileDrawerContent(
            avatarUrl: null,
            name: 'Shanel Hassan',
            roleLabel: admin ? 'Admin' : 'Assistant',
            email: 'shanel@example.com',
            phone: '+255 712 345 678',
            facility: facility,
            facilityType: 'Agrovet',
            onClose: () {},
            actions: _actions(admin: admin),
          ),
    ),
  );
}

void main() {
  for (final size in _sizes) {
    final at = '${size.width.toInt()}x${size.height.toInt()}';
    for (final admin in [true, false]) {
      for (final look in [MatrixLook.light, MatrixLook.kiswahili]) {
        final name = 'ui3-profile-drawer-${admin ? 'admin' : 'assistant'}-${look.name}-$at';
        testWidgets('$name: only the Facility row may change', (tester) async {
          await pumpAtSize(tester, screen: ui3DrawerPage(admin: admin), size: size, look: look);
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          expectSameFingerprint(name, treeFingerprint(tester, find.byType(Drawer)));
        });
      }
    }
  }
}
