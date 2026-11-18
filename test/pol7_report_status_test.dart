// POL7: the ONE report status mapping (reportAppStatus), from the STORED
// value ('draft' | 'submitted'), pinned; the words shown are unchanged
// and always shown beside the dot, in every theme, Light and Dark.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/theme/app_colors.dart';
import 'package:vetbiz_pro/theme/app_palette.dart';
import 'package:vetbiz_pro/theme/app_theme.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';

void main() {
  test('the mapping: submitted done, draft waits, anything else neutral', () {
    expect(reportAppStatus('submitted'), AppStatus.success);
    expect(reportAppStatus('draft'), AppStatus.warning);
    expect(reportAppStatus('Submitted'), AppStatus.neutral);
    expect(reportAppStatus(''), AppStatus.neutral);
  });

  test('the words are the existing ones', () {
    final en = lookupAppLocalizations(const Locale('en'));
    expect(en.reports_notSubmitted, isNotEmpty);
    expect(en.reports_completed, isNotEmpty);
    expect(en.reports_draftNotSubmitted, isNotEmpty);
    expect(en.subscription_colSubmitted, isNotEmpty);
  });

  for (final theme in AppColorTheme.all) {
    for (final b in Brightness.values) {
      testWidgets('${theme.name} ${b.name}: the dot takes the state role, the word is shown', (tester) async {
        final c = AppColors.fromTheme(theme, brightness: b);
        await tester.pumpWidget(MaterialApp(
          theme: AppTheme.build(theme, b),
          home: Scaffold(
            body: Column(children: [
              StatusDot(status: reportAppStatus('draft'), label: 'Draft'),
              StatusDot(status: reportAppStatus('submitted'), label: 'Submitted'),
            ]),
          ),
        ));
        expect(find.text('Draft'), findsOneWidget);
        expect(find.text('Submitted'), findsOneWidget);
        final dots = tester.widgetList<DecoratedBox>(find.descendant(
            of: find.byKey(const ValueKey('statusDot-dot')), matching: find.byType(DecoratedBox)));
        expect([for (final d in dots) (d.decoration as BoxDecoration).color], [c.warning, c.success]);
      });
    }
  }
}
