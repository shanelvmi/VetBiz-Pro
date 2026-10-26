import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/config/app_timeouts.dart';
import 'package:vetbiz_pro/data/announcement_fields.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/utils/updates_selection.dart';
import 'package:vetbiz_pro/widgets/announcement_message.dart';

// AN2, written before the code: which announcements the login page's Updates
// shows. Hidden ones never; en or sw only in that UI language ('all' or
// missing always); if any shown one is urgent, only the urgent ones; at most
// five, newest first (the query's order is kept).

Announcement _a(String id, {String? audience, bool urgent = false, bool hidden = false, String? kind, DateTime? at}) =>
    Announcement.fromMap(id, {
      'title': 'T $id',
      'message': 'M $id',
      if (audience != null) 'audience': audience,
      if (kind != null) 'kind': kind,
      'urgent': urgent,
      'hidden': hidden,
      if (at != null) 'timestamp': Timestamp.fromDate(at),
    });

List<String> _ids(List<Announcement> list) => [for (final a in list) a.id];

void main() {
  test('hidden ones never show', () {
    expect(_ids(UpdatesSelection.pick([_a('1'), _a('2', hidden: true)], languageCode: 'en')), ['1']);
  });

  test('the audience filter, in English and in Kiswahili', () {
    final all = [_a('none'), _a('all', audience: 'all'), _a('en', audience: 'en'), _a('sw', audience: 'sw'), _a('odd', audience: 'fr')];
    expect(_ids(UpdatesSelection.pick(all, languageCode: 'en')), ['none', 'all', 'en', 'odd']);
    expect(_ids(UpdatesSelection.pick(all, languageCode: 'sw')), ['none', 'all', 'sw', 'odd']);
  });

  test('any urgent shown one: only the urgent ones show', () {
    final all = [_a('1'), _a('2', urgent: true), _a('3'), _a('4', urgent: true)];
    expect(_ids(UpdatesSelection.pick(all, languageCode: 'en')), ['2', '4']);
  });

  test('an urgent one hidden, or for the other language, does not silence the rest', () {
    final all = [_a('1'), _a('2', urgent: true, hidden: true), _a('3', urgent: true, audience: 'sw')];
    expect(_ids(UpdatesSelection.pick(all, languageCode: 'en')), ['1']);
  });

  test('at most five, in the order given (newest first)', () {
    final all = [for (var i = 1; i <= 8; i++) _a('$i')];
    expect(AppLimits.updatesMaxSlides, 5);
    expect(_ids(UpdatesSelection.pick(all, languageCode: 'en')), ['1', '2', '3', '4', '5']);
  });

  test('a document without kind is a text slide', () {
    expect(_a('x').kind, AnnouncementKind.text);
    expect(_a('p', kind: 'poster').kind, AnnouncementKind.poster);
  });

  test('New for the first 48 hours, as before', () {
    final now = DateTime(2026, 10, 26, 12);
    expect(AppTimeouts.updatesNewFor, const Duration(hours: 48));
    expect(UpdatesSelection.isNew(_a('1', at: now.subtract(const Duration(hours: 47))), now), isTrue);
    expect(UpdatesSelection.isNew(_a('1', at: now.subtract(const Duration(hours: 49))), now), isFalse);
    expect(UpdatesSelection.isNew(_a('1'), now), isFalse);
  });

  test('the slides advance every 7 seconds', () {
    expect(AppTimeouts.updatesAdvance, const Duration(seconds: 7));
  });

  test('a message as plain text for a slide: formatting marks and colour tags gone, link text kept', () {
    expect(
      AnnouncementMessage.plainText('**New** prices _today_. {color:#D32F2F}Hurry{/color}, see [the list](https://a.example).'),
      'New prices today. Hurry, see the list.',
    );
    expect(AnnouncementMessage.plainText('One\n\nTwo'), 'One\nTwo');
    expect(AnnouncementMessage.plainText(''), '');
  });
}
