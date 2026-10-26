import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/widgets/updates_carousel.dart';

import 'helpers/updates_harness.dart';

// AN2 (the owner's approved design), written before the widget: ONE fixed
// 16:9 frame; a text slide centred with New and Important inside it; a
// poster with those chips in the label row above, never on the image, and
// its title on a neutral panel if the image fails; Read more for a long
// message; the link button below, only for a safe http or https address.

void main() {
  setUp(() => UpdatesSlides.debugTimerStarts = 0);

  group('the frame and the slides', () {
    testWidgets('a 16:9 frame on a phone and on a wide window', (tester) async {
      for (final width in [390.0, 1200.0]) {
        await pumpSlides(tester, [textUpdate('1')], width: width);
        final r = frame(tester);
        expect(r.width / r.height, closeTo(AppLimits.posterAspectRatio, 0.01), reason: '$width');
      }
    });

    testWidgets('the label reads Updates (Taarifa in Kiswahili); no icon, no chevron, no Announcements', (tester) async {
      await pumpSlides(tester, [textUpdate('1')]);
      expect(find.text(enL10n.updates_label), findsOneWidget);
      expect(find.text('Announcements'), findsNothing);
      expect(find.descendant(of: find.byKey(UpdatesSlides.labelRowKey), matching: find.byType(Icon)), findsNothing);
      expect(find.byIcon(Icons.chevron_right), findsNothing);
      expect(find.byIcon(Icons.campaign_outlined), findsNothing);
      await pumpSlides(tester, [textUpdate('1')], locale: const Locale('sw'));
      expect(find.text(swL10n.updates_label), findsOneWidget);
    });

    testWidgets('a text slide: the title and message centred in the frame, New and Important inside it', (tester) async {
      await pumpSlides(tester, [textUpdate('1', urgent: true, fresh: true)]);
      final r = frame(tester);
      final title = tester.getRect(find.text('Title 1'));
      final message = tester.getRect(find.text('A short message'));
      expect(title.center.dx, closeTo(r.center.dx, 1));
      expect(message.center.dx, closeTo(r.center.dx, 1));
      expect((title.top - r.top) - (r.bottom - message.bottom), closeTo(0, 2));
      for (final chip in [enL10n.updates_new, enL10n.updates_important]) {
        expect(r.contains(tester.getCenter(find.text(chip))), isTrue, reason: chip);
      }
    });

    testWidgets('a poster: the image fills the frame; New and Important sit in the label row, never on the image', (
      tester,
    ) async {
      await pumpSlides(tester, [posterUpdate('1', urgent: true, fresh: true)]);
      final image = tester.widget<Image>(find.descendant(of: find.byKey(UpdatesSlides.frameKey), matching: find.byType(Image)));
      expect(image.fit, BoxFit.cover);
      final r = frame(tester);
      for (final chip in [enL10n.updates_new, enL10n.updates_important]) {
        expect(find.descendant(of: find.byKey(UpdatesSlides.labelRowKey), matching: find.text(chip)), findsOneWidget);
        expect(tester.getRect(find.text(chip)).bottom, lessThanOrEqualTo(r.top));
      }
    });

    testWidgets('a poster whose image fails shows a neutral panel with its title', (tester) async {
      await pumpSlides(tester, [posterUpdate('1')], imageFor: badImage);
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
      await tester.pump();
      expect(find.descendant(of: find.byKey(UpdatesSlides.frameKey), matching: find.text('Poster 1')), findsOneWidget);
    });

    testWidgets('a long message ends in an ellipsis with Read more, which opens the whole message', (tester) async {
      final message = longText('Habari', 120);
      await pumpSlides(tester, [textUpdate('1', message: message)], width: 390);
      expect(find.text(enL10n.updates_readMore), findsOneWidget);
      await tester.tap(find.text(enL10n.updates_readMore));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        find.descendant(of: find.byType(AlertDialog), matching: find.textContaining(message, findRichText: true)),
        findsOneWidget,
      );
    });

    testWidgets('a short message has no Read more', (tester) async {
      await pumpSlides(tester, [textUpdate('1')]);
      expect(find.text(enL10n.updates_readMore), findsNothing);
    });
  });

  group('the link button', () {
    testWidgets('shown only for a valid http or https address, and opened outside the app', (tester) async {
      final opened = <(Uri, LaunchMode)>[];
      Future<bool> launcher(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
        opened.add((url, mode));
        return true;
      }

      for (final bad in ['javascript:alert(1)', 'ftp://a.example/x', 'vetbiz', '']) {
        await pumpSlides(tester, [textUpdate('1', link: bad, label: 'Open')], launcher: launcher);
        expect(find.byKey(UpdatesSlides.linkKey), findsNothing, reason: bad);
      }
      await pumpSlides(tester, [textUpdate('1', link: 'https://a.example/learn', label: 'Learn more')], launcher: launcher);
      expect(find.descendant(of: find.byKey(UpdatesSlides.linkKey), matching: find.text('Learn more')), findsOneWidget);
      // Below the slide.
      expect(tester.getRect(find.byKey(UpdatesSlides.linkKey)).top, greaterThanOrEqualTo(frame(tester).bottom));
      await tester.tap(find.byKey(UpdatesSlides.linkKey));
      await tester.pump();
      expect(opened, [(Uri.parse('https://a.example/learn'), LaunchMode.externalApplication)]);
    });
  });
}
