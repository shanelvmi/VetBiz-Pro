import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/theme/app_dimens.dart';
import 'package:vetbiz_pro/widgets/announcement_poster.dart';

import 'helpers/updates_harness.dart';

// AN3, written before the widgets: the poster pieces shared by the bell's
// dropdown and any later reader - a 16:9 thumbnail about 64 px wide with a
// skeleton and a neutral fallback, the full poster in a dialog, and the one
// link button rule (only a safe http or https address, opened outside).

Announcement _poster({String? link, String? label, String message = ''}) => Announcement.fromMap('P1', {
      'kind': 'poster',
      'title': 'Vaccination week',
      'message': message,
      'imageUrl': 'https://files.example/p.png',
      'urgent': true,
      if (link != null) 'linkUrl': link,
      if (label != null) 'linkLabel': label,
    });

void main() {
  Future<void> pump(WidgetTester tester, Widget child, {double width = 390}) async {
    tester.view.physicalSize = Size(width, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(updatesApp(Center(child: child)));
    await tester.pump();
  }

  testWidgets('the thumbnail: 64 px wide, 16:9, the image covering it', (tester) async {
    await pump(tester, AnnouncementThumbnail(announcement: _poster(), imageFor: goodImage));
    final size = tester.getSize(find.byType(AnnouncementThumbnail));
    expect(size.width, AppSizes.posterThumbnail);
    expect(AppSizes.posterThumbnail, 64);
    expect(size.width / size.height, closeTo(AppLimits.posterAspectRatio, 0.05));
    expect(tester.widget<Image>(find.byType(Image)).fit, BoxFit.cover);
  });

  testWidgets('a thumbnail whose image fails: a neutral panel, no error', (tester) async {
    await pump(tester, AnnouncementThumbnail(announcement: _poster(), imageFor: badImage));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.byKey(AnnouncementThumbnail.fallbackKey), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the dialog: the whole poster in a 16:9 frame, its title, the message, Close', (tester) async {
    await pump(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showAnnouncementPoster(context, _poster(message: 'All week'), imageFor: goodImage),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    final dialog = find.byType(Dialog);
    expect(dialog, findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('Vaccination week')), findsWidgets);
    expect(find.descendant(of: dialog, matching: find.textContaining('All week', findRichText: true)), findsOneWidget);
    final frame = tester.getSize(find.byKey(AnnouncementPosterView.frameKey));
    expect(frame.width / frame.height, closeTo(AppLimits.posterAspectRatio, 0.01));
    await tester.tap(find.text(enL10n.common_close));
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
  });

  testWidgets('the dialog with a failed image: the title on a neutral panel', (tester) async {
    await pump(tester, AnnouncementPosterView(announcement: _poster(), imageFor: badImage));
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 200)));
    await tester.pump();
    expect(find.descendant(of: find.byKey(AnnouncementPosterView.frameKey), matching: find.text('Vaccination week')),
        findsOneWidget);
  });

  testWidgets('the link button: only for a safe http or https address, opened outside the app', (tester) async {
    final opened = <(Uri, LaunchMode)>[];
    Future<bool> launcher(Uri url, {LaunchMode mode = LaunchMode.platformDefault}) async {
      opened.add((url, mode));
      return true;
    }

    for (final (link, label) in [('javascript:alert(1)', 'Go'), ('ftp://a.example', 'Go'), ('https://a.example', '')]) {
      await pump(tester, AnnouncementLinkButton(announcement: _poster(link: link, label: label), launcher: launcher));
      expect(find.byType(TextButton), findsNothing, reason: link);
      expect(AnnouncementLinkButton.addressOf(_poster(link: link, label: label)), isNull);
    }
    await pump(tester, AnnouncementLinkButton(announcement: _poster(link: 'a.example/book', label: 'Book now'), launcher: launcher));
    expect(find.text('Book now'), findsOneWidget);
    expect(tester.getSize(find.byType(TextButton)).height, greaterThanOrEqualTo(kMinInteractiveDimension));
    await tester.tap(find.text('Book now'));
    await tester.pump();
    expect(opened, [(Uri.parse('https://a.example/book'), LaunchMode.externalApplication)]);
  });

  testWidgets('no overflow in the dialog at 360 with a long title and message, Light and Dark, Kiswahili', (tester) async {
    final long = Announcement.fromMap('P2', {
      'kind': 'poster',
      'title': List.filled(12, 'Mafunzo').join(' '),
      'message': List.filled(40, 'Wafugaji').join(' '),
      'imageUrl': 'https://files.example/p.png',
      'linkUrl': 'https://a.example',
      'linkLabel': 'Jifunze zaidi sasa',
    });
    for (final brightness in Brightness.values) {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(updatesApp(
        AnnouncementPosterView(announcement: long, imageFor: goodImage),
        brightness: brightness,
        locale: const Locale('sw'),
      ));
      await tester.pump();
      expect(tester.takeException(), isNull, reason: '$brightness');
    }
  });
}
