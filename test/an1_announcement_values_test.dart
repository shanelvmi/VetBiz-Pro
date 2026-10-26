import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/config/app_limits.dart';
import 'package:vetbiz_pro/data/announcement_fields.dart';

// AN1: the stored values of an announcement never change (RUNBOOK section 2:
// every new list of stored values gets a test pinning its values and order).

void main() {
  test('kinds: text then poster, stored as typed', () {
    expect(AnnouncementKind.values.map((k) => k.key), ['text', 'poster']);
  });

  test('audiences: all, en, sw, stored as typed', () {
    expect(AnnouncementAudience.values.map((a) => a.key), ['all', 'en', 'sw']);
  });

  test('a document from before AN1 (no kind, no audience) reads as text for everyone; unknown values too', () {
    expect(AnnouncementKind.fromStored(null), AnnouncementKind.text);
    expect(AnnouncementKind.fromStored('video'), AnnouncementKind.text);
    expect(AnnouncementKind.fromStored('poster'), AnnouncementKind.poster);
    expect(AnnouncementAudience.fromStored(null), AnnouncementAudience.all);
    expect(AnnouncementAudience.fromStored('fr'), AnnouncementAudience.all);
    expect(AnnouncementAudience.fromStored('sw'), AnnouncementAudience.sw);
  });

  test('field names and the Storage folder (storage.rules announcement_posters/)', () {
    expect(
      [
        AnnouncementFields.kind, AnnouncementFields.title, AnnouncementFields.message,
        AnnouncementFields.imageUrl, AnnouncementFields.imagePath, AnnouncementFields.imageWidth,
        AnnouncementFields.imageHeight, AnnouncementFields.audience, AnnouncementFields.linkUrl,
        AnnouncementFields.linkLabel, AnnouncementFields.urgent, AnnouncementFields.hidden,
        AnnouncementFields.timestamp,
      ],
      ['kind', 'title', 'message', 'imageUrl', 'imagePath', 'imageWidth', 'imageHeight', 'audience',
       'linkUrl', 'linkLabel', 'urgent', 'hidden', 'timestamp'],
    );
    expect(AnnouncementFields.posterFolder, 'announcement_posters');
  });

  test('the limits the owner set', () {
    expect(AppLimits.posterImageMaxSide, 1600);
    expect(AppLimits.posterMinWidth, 1280);
    expect(AppLimits.posterAspectRatio, 16 / 9);
    expect(AppLimits.posterRatioTolerance, 0.03);
    expect(AppLimits.posterMaxBytes, 1024 * 1024);
    expect([AppLimits.announcementTitleMin, AppLimits.announcementTitleMax], [2, 80]);
    expect([AppLimits.announcementMessageMin, AppLimits.announcementMessageMax], [2, 400]);
    expect(AppLimits.posterMessageMax, 200);
    expect([AppLimits.announcementLinkLabelMin, AppLimits.announcementLinkLabelMax], [2, 24]);
    expect(AppLimits.updatesMaxSlides, 5);
  });
}
