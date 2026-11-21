// UX1a: the wide top bar's search, bell, Help and profile sit against the
// window's right edge at every PC/tablet width, sidebar open or collapsed.
// Before UX1a the search (a Flexible) and a Spacer shared the free space in
// half, so on a wide window the trailing buttons stopped mid-bar.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/widgets/profile/profile_menu_button.dart';
import 'package:vetbiz_pro/widgets/shell/app_sidebar.dart';
import 'package:vetbiz_pro/widgets/shell/wide_top_bar.dart';

import 'helpers/screen_size_matrix.dart';

const _profileKey = ValueKey('ux1a-profile');
const _trailingEnd = ValueKey('ux1a-trailing-end');

/// The window as the dashboard lays it out: the sidebar (or rail) and the top
/// bar beside it, with the dashboard's trailing buttons (the profile button
/// sits in a 12 right padding, as in _buildProfileButton).
Widget _window(double sidebar) => Scaffold(
      body: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: sidebar),
          Expanded(
            child: WideTopBar(
              leading: IconButton(onPressed: () {}, icon: const Icon(Icons.menu)),
              search: const SizedBox(key: ValueKey('search'), height: 38, width: double.infinity),
              onSearchIcon: () {},
              trailing: [
                IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none)),
                IconButton(onPressed: () {}, icon: const Icon(Icons.help_outline)),
                const SizedBox(width: AppSpacing.s4),
                Padding(
                  key: _trailingEnd,
                  padding: const EdgeInsets.only(right: AppSpacing.s12),
                  child: ProfileMenuButton(
                      key: _profileKey, avatarUrl: null, name: 'Mwanaisha Abdallah Khamis', roleLabel: 'Co-admin', onTap: () {}),
                ),
              ],
            ),
          ),
        ],
      ),
    );

void main() {
  for (final width in [768.0, 1024.0, 1200.0, 1920.0]) {
    // The tablet (768) has the rail only; a computer the sidebar open or collapsed.
    final sidebars = width < 1024 ? [AppSidebar.railWidth] : [AppSidebar.expandedWidth, AppSidebar.railWidth];
    for (final sidebar in sidebars) {
      for (final look in const [MatrixLook.light, MatrixLook.kiswahili]) {
        testWidgets('window ${width.toInt()}, sidebar ${sidebar.toInt()}, ${look.name}, text 1.3: the profile at the right edge',
            (tester) async {
          await pumpAtSize(tester, size: Size(width, 800), look: look, textScale: 1.3, screen: _window(sidebar));
          expect(tester.takeException(), isNull, reason: 'no overflow');
          // The trailing group ends at the bar's right padding, and the
          // profile button within it.
          expect(tester.getTopRight(find.byKey(_trailingEnd)).dx, width - AppSpacing.s16);
          expect(tester.getTopRight(find.byKey(_profileKey)).dx, width - AppSpacing.s16 - AppSpacing.s12);
          // The search keeps its 260 at most and sits just left of the bell.
          final search = find.byKey(const ValueKey('search'));
          expect(tester.getSize(search).width, lessThanOrEqualTo(WideTopBar.searchMaxWidth));
          final bell = find.widgetWithIcon(IconButton, Icons.notifications_none);
          expect(tester.getTopLeft(bell).dx - tester.getTopRight(search).dx, AppSpacing.s12);
        });
      }
    }
  }

  testWidgets('below 720 the search is the icon, still at the right', (tester) async {
    await pumpAtSize(tester, size: const Size(700, 800), textScale: 1.3, screen: _window(0));
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('top-bar-search-icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('search')), findsNothing);
    expect(tester.getTopRight(find.byKey(_trailingEnd)).dx, 700 - AppSpacing.s16);
  });
}
