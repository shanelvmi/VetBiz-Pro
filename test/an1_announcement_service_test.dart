import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/announcement_fields.dart';
import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/upload_content_types.dart';
import 'package:vetbiz_pro/services/announcement_service.dart';
import 'package:vetbiz_pro/utils/poster_image_check.dart';

// AN1 (docs/design/announcements_v2.md sections 2 and 5), written before the
// code: the document written for text and for poster, the validation, the
// link through SocialLink, the audience, an old document opening as text,
// and the order of upload, write and cleanup.

class _FakeStore implements PosterStore {
  final files = <String, String>{}; // path -> content type
  bool failUpload = false;
  Object? deleteError;

  @override
  Future<String> upload(String path, Uint8List bytes, PosterImageType type) async {
    if (failUpload) throw FirebaseException(plugin: 'firebase_storage', code: 'unauthorized');
    files[path] = type.contentType;
    return 'https://files.example/$path?alt=media';
  }

  @override
  Future<void> delete(String path) async {
    if (deleteError != null) throw deleteError!;
    if (files.remove(path) == null) throw FirebaseException(plugin: 'firebase_storage', code: 'object-not-found');
  }
}

PosterImage _poster([PosterImageType type = PosterImageType.webp]) =>
    PosterImage(bytes: Uint8List(8), type: type, width: 1600, height: 900);

AnnouncementDraft _text({String title = 'Price update', String message = 'New prices from Monday', String link = '', String label = ''}) =>
    AnnouncementDraft(kind: AnnouncementKind.text, title: title, message: message, linkUrl: link, linkLabel: label);

AnnouncementDraft _posterDraft({PosterImage? image, String message = ''}) => AnnouncementDraft(
    kind: AnnouncementKind.poster, title: 'New feature', message: message, audience: AnnouncementAudience.sw, image: image);

void main() {
  late FakeFirebaseFirestore db;
  late _FakeStore store;
  var failWrite = false;
  late AnnouncementService service;

  setUp(() {
    db = FakeFirebaseFirestore();
    store = _FakeStore();
    failWrite = false;
    service = AnnouncementService(
      firestore: db,
      store: store,
      now: () => DateTime.fromMillisecondsSinceEpoch(1700000000000),
      beforeDocumentWrite: () async {
        if (failWrite) throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
      },
    );
  });

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> docs() async =>
      (await db.collection(Collections.publicAnnouncements).get()).docs;

  Future<Announcement> only() async {
    final all = await docs();
    expect(all, hasLength(1));
    return Announcement.fromMap(all.single.id, all.single.data());
  }

  group('validation', () {
    test('title 2 to 80; text message 2 to 400; poster caption optional, up to 200', () {
      expect(AnnouncementService.validate(_text()).isEmpty, isTrue);
      expect(AnnouncementService.validate(_text(title: 'A')).title, AnnouncementService.titleLength);
      expect(AnnouncementService.validate(_text(title: 'A' * 81)).title, AnnouncementService.titleLength);
      expect(AnnouncementService.validate(_text(message: ' ')).message, AnnouncementService.messageLength);
      expect(AnnouncementService.validate(_text(message: 'x' * 401)).message, AnnouncementService.messageLength);
      expect(AnnouncementService.validate(_text(message: 'x' * 400)).isEmpty, isTrue);
      expect(AnnouncementService.validate(_posterDraft(image: _poster())).isEmpty, isTrue);
      expect(AnnouncementService.validate(_posterDraft(image: _poster(), message: 'x' * 201)).message,
          AnnouncementService.captionLength);
    });

    test('a poster needs an image', () {
      expect(AnnouncementService.validate(_posterDraft()).image, AnnouncementService.imageMissing);
    });

    test('the link goes through SocialLink: javascript: refused, a bare host gets https://; the label then 2 to 24', () {
      expect(AnnouncementService.validate(_text(link: 'javascript:alert(1)', label: 'Open')).link, AnnouncementService.linkInvalid);
      expect(AnnouncementService.validate(_text(link: 'vetbiz', label: 'Open')).link, AnnouncementService.linkInvalid);
      expect(AnnouncementService.validate(_text(link: 'example.com/x')).linkLabel, AnnouncementService.labelLength);
      expect(AnnouncementService.validate(_text(link: 'example.com/x', label: 'L' * 25)).linkLabel, AnnouncementService.labelLength);
      expect(AnnouncementService.validate(_text(label: 'Open')).link, AnnouncementService.labelWithoutLink);
      expect(AnnouncementService.validate(_text(link: 'example.com/x', label: 'Open')).isEmpty, isTrue);
    });

    test('an old title or message longer than the new limits passes while unchanged', () {
      final old = Announcement.fromMap('old', {'title': 'T' * 90, 'message': 'm' * 500});
      expect(AnnouncementService.validate(_text(title: 'T' * 90, message: 'm' * 500), previous: old).isEmpty, isTrue);
      expect(AnnouncementService.validate(_text(title: 'T' * 91, message: 'm' * 500), previous: old).title, isNotNull);
    });
  });

  group('reading', () {
    test('an old document without kind or audience opens as text for everyone', () {
      final a = Announcement.fromMap('old', {'title': 'Hello', 'message': 'World', 'urgent': true});
      expect(a.kind, AnnouncementKind.text);
      expect(a.audience, AnnouncementAudience.all);
      expect(a.urgent, isTrue);
      expect(a.hidden, isFalse);
      expect(a.imagePath, isNull);
      expect(a.linkUrl, '');
    });
  });

  group('the document written', () {
    test('text: kind, title, message, audience, link, urgent, hidden false, a timestamp; no image fields', () async {
      await service.save(_text(link: 'example.com/learn', label: ' Learn more ')
        ..urgent = true
        ..audience = AnnouncementAudience.en);
      final data = (await docs()).single.data();
      expect(data[AnnouncementFields.kind], 'text');
      expect(data[AnnouncementFields.title], 'Price update');
      expect(data[AnnouncementFields.message], 'New prices from Monday');
      expect(data[AnnouncementFields.audience], 'en');
      expect(data[AnnouncementFields.linkUrl], 'https://example.com/learn');
      expect(data[AnnouncementFields.linkLabel], 'Learn more');
      expect(data[AnnouncementFields.urgent], isTrue);
      expect(data[AnnouncementFields.hidden], isFalse);
      expect(data[AnnouncementFields.timestamp], isA<Timestamp>());
      expect(data.containsKey(AnnouncementFields.imageUrl), isFalse);
      expect(store.files, isEmpty);
    });

    test('poster: uploaded first with its real type, then the document with url, path and size; no empty message', () async {
      await service.save(_posterDraft(image: _poster()));
      final a = await only();
      expect(a.kind, AnnouncementKind.poster);
      expect(a.audience, AnnouncementAudience.sw);
      expect(a.imagePath, 'announcement_posters/${a.id}-1700000000000.webp');
      expect(store.files, {a.imagePath: 'image/webp'});
      expect(a.imageUrl, 'https://files.example/${a.imagePath}?alt=media');
      expect([a.imageWidth, a.imageHeight], [1600, 900]);
      expect((await docs()).single.data().containsKey(AnnouncementFields.message), isFalse);
      expect((await docs()).single.data().containsKey(AnnouncementFields.linkUrl), isFalse);
    });
  });

  group('cleanup', () {
    test('the upload fails: nothing is written', () async {
      store.failUpload = true;
      await expectLater(service.save(_posterDraft(image: _poster())), throwsA(isA<FirebaseException>()));
      expect(await docs(), isEmpty);
    });

    test('the document write fails: the uploaded image is deleted', () async {
      failWrite = true;
      await expectLater(service.save(_posterDraft(image: _poster())), throwsA(isA<FirebaseException>()));
      expect(await docs(), isEmpty);
      expect(store.files, isEmpty);
    });

    test('editing with a new image: the old file is deleted after the document is saved', () async {
      await service.save(_posterDraft(image: _poster()));
      final before = await only();
      service = AnnouncementService(firestore: db, store: store, now: () => DateTime.fromMillisecondsSinceEpoch(1700000099999));
      expect(await service.save(_posterDraft(image: _poster(PosterImageType.jpeg)), existing: before), isTrue);
      final after = await only();
      expect(after.imagePath, 'announcement_posters/${before.id}-1700000099999.jpg');
      expect(store.files.keys, [after.imagePath]);
    });

    test('editing with a new image whose write fails: the new file goes, the old stays', () async {
      await service.save(_posterDraft(image: _poster()));
      final before = await only();
      failWrite = true;
      await expectLater(service.save(_posterDraft(image: _poster(PosterImageType.png)), existing: before), throwsA(anything));
      expect(store.files.keys, [before.imagePath]);
      expect((await only()).imagePath, before.imagePath);
    });

    test('editing a poster without a new image keeps its file and image fields', () async {
      await service.save(_posterDraft(image: _poster()));
      final before = await only();
      await service.save(_posterDraft(message: 'Caption'), existing: before);
      final after = await only();
      expect(after.imagePath, before.imagePath);
      expect(after.message, 'Caption');
      expect(store.files.keys, [before.imagePath]);
    });

    test('a poster turned into text loses its image fields, then its file', () async {
      await service.save(_posterDraft(image: _poster()));
      await service.save(_text(), existing: await only());
      final data = (await docs()).single.data();
      expect(data[AnnouncementFields.kind], 'text');
      for (final f in [AnnouncementFields.imageUrl, AnnouncementFields.imagePath, AnnouncementFields.imageWidth, AnnouncementFields.imageHeight]) {
        expect(data.containsKey(f), isFalse, reason: f);
      }
      expect(store.files, isEmpty);
    });

    test('delete: the document, then its file; a missing file is not an error; other errors are reported', () async {
      await service.save(_posterDraft(image: _poster()));
      final a = await only();
      store.files.clear();
      expect(await service.delete(a), isTrue);
      expect(await docs(), isEmpty);

      await service.save(_posterDraft(image: _poster()));
      store.deleteError = FirebaseException(plugin: 'firebase_storage', code: 'unauthorized');
      expect(await service.delete(await only()), isFalse);
      expect(await docs(), isEmpty);
    });
  });

  group('old text announcements', () {
    test('open, edit and save unchanged: hidden and timestamp kept, link cleared', () async {
      final ref = db.collection(Collections.publicAnnouncements).doc('old');
      final ts = Timestamp.fromMillisecondsSinceEpoch(1600000000000);
      await ref.set({'title': 'T' * 90, 'message': 'Old', 'urgent': false, 'hidden': true, 'timestamp': ts, 'linkUrl': 'https://a.example', 'linkLabel': 'Go'});
      final old = Announcement.fromMap('old', (await ref.get()).data()!);
      final draft = AnnouncementDraft.from(old)..linkUrl = '';
      draft.linkLabel = '';
      await service.save(draft, existing: old);
      final data = (await ref.get()).data()!;
      expect(data['title'], 'T' * 90);
      expect(data['message'], 'Old');
      expect(data['hidden'], isTrue);
      expect(data['timestamp'], ts);
      expect(data[AnnouncementFields.kind], 'text');
      expect(data.containsKey(AnnouncementFields.linkUrl), isFalse);
      expect(data.containsKey(AnnouncementFields.linkLabel), isFalse);
    });
  });
}
