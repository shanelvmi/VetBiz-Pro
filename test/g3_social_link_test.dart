import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/data/collections.dart';
import 'package:vetbiz_pro/data/support_contact_fields.dart';
import 'package:vetbiz_pro/models/support_contact.dart';
import 'package:vetbiz_pro/utils/social_link.dart';

// G3 (the sign-in footer): the one social-link sanitiser and the support
// contact read. Written before the code, skipped until it exists.
const _skip = true;

void main() {
  group('SocialLink.sanitize', skip: _skip, () {
    test('empty is allowed and means "not set"', () {
      expect(SocialLink.sanitize(null), '');
      expect(SocialLink.sanitize(''), '');
      expect(SocialLink.sanitize('   '), '');
    });

    test('a bare host or a www. address gets https:// added', () {
      expect(SocialLink.sanitize('facebook.com/vetbizpro'), 'https://facebook.com/vetbizpro');
      expect(SocialLink.sanitize('www.instagram.com/vetbiz'), 'https://www.instagram.com/vetbiz');
      expect(SocialLink.sanitize('  x.com/vetbiz  '), 'https://x.com/vetbiz');
    });

    test('http and https are kept as typed', () {
      expect(SocialLink.sanitize('http://example.co.tz/page'), 'http://example.co.tz/page');
      expect(SocialLink.sanitize('https://www.youtube.com/@vetbiz'), 'https://www.youtube.com/@vetbiz');
      expect(SocialLink.sanitize('HTTPS://www.tiktok.com/@vetbiz'), 'https://www.tiktok.com/@vetbiz');
    });

    test('no host is refused', () {
      expect(SocialLink.sanitize('https://'), isNull);
      expect(SocialLink.sanitize('https:///path'), isNull);
      expect(SocialLink.sanitize('http://localhost'), isNull);
    });

    test('spaces inside are refused', () {
      expect(SocialLink.sanitize('facebook.com/vet biz'), isNull);
      expect(SocialLink.sanitize('https://www.face book.com'), isNull);
    });

    test('other schemes are refused', () {
      expect(SocialLink.sanitize('javascript:alert(1)'), isNull);
      expect(SocialLink.sanitize('data:text/html,<b>hi</b>'), isNull);
      expect(SocialLink.sanitize('ftp://files.example.com'), isNull);
      expect(SocialLink.sanitize('mailto:a@b.co'), isNull);
    });

    test('garbage is refused', () {
      expect(SocialLink.sanitize('not a link'), isNull);
      expect(SocialLink.sanitize('vetbiz'), isNull);
      expect(SocialLink.sanitize('!!!'), isNull);
      expect(SocialLink.sanitize('https://%%%'), isNull);
    });
  });

  group('SocialLink.isLaunchable', skip: _skip, () {
    test('only http and https with a host', () {
      expect(SocialLink.isLaunchable(Uri.parse('https://facebook.com/x')), isTrue);
      expect(SocialLink.isLaunchable(Uri.parse('http://x.com/y')), isTrue);
      expect(SocialLink.isLaunchable(Uri.parse('javascript:alert(1)')), isFalse);
      expect(SocialLink.isLaunchable(Uri.parse('ftp://files.example.com')), isFalse);
      expect(SocialLink.isLaunchable(Uri.parse('https:///path')), isFalse);
    });
  });

  group('SupportContact', skip: _skip, () {
    test('the network order is pinned (stored keys and icon order)', () {
      expect(SocialNetwork.values.map((n) => n.field).toList(),
          ['facebook', 'instagram', 'x', 'linkedin', 'youtube', 'tiktok']);
    });

    test('reads the contact rows trimmed, and an empty or missing document is empty', () {
      final c = SupportContact.fromMap({'email': ' help@vetbiz.co.tz ', 'phone': '+255 700 000 000', 'whatsapp': 7});
      expect(c.email, 'help@vetbiz.co.tz');
      expect(c.phone, '+255 700 000 000');
      expect(c.whatsapp, '');
      expect(c.address, '');
      expect(SupportContact.fromMap(null).hasContactRows, isFalse);
      expect(SupportContact.fromMap(const {}).socialLinks, isEmpty);
    });

    test('only valid links are kept, in the pinned order whatever the map order', () {
      final c = SupportContact.fromMap({
        'tiktok': 'tiktok.com/@vetbiz',
        'facebook': 'https://facebook.com/vetbiz',
        'instagram': 'javascript:alert(1)',
        'x': 'data:text/html,hi',
        'linkedin': 'ftp://linkedin.com/x',
        'youtube': '',
      });
      expect(c.socialLinks.map((e) => e.key).toList(), [SocialNetwork.facebook, SocialNetwork.tiktok]);
      expect(c.socialLinks.last.value.toString(), 'https://tiktok.com/@vetbiz');
    });

    test('load reads app_config/support_contact; a missing document is empty', () async {
      final db = FakeFirebaseFirestore();
      expect((await SupportContact.load(db)).hasContactRows, isFalse);
      await db.collection(Collections.appConfig).doc(SupportContactFields.docId).set({'email': 'a@b.co', 'instagram': 'instagram.com/v'});
      final c = await SupportContact.load(db);
      expect(c.email, 'a@b.co');
      expect(c.socialLinks.single.key, SocialNetwork.instagram);
    });
  });
}
