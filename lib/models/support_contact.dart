import 'package:cloud_firestore/cloud_firestore.dart';

import '../data/support_contact_fields.dart';

/// What app_config/support_contact holds, read once. Every field is
/// optional: an empty or unreadable document gives [SupportContact.empty],
/// and the Help dialog then shows only its generic sentence.
class SupportContact {
  const SupportContact({
    this.email = '',
    this.phone = '',
    this.whatsapp = '',
    this.address = '',
    this.social = const {},
  });

  static const empty = SupportContact();

  final String email;
  final String phone;
  final String whatsapp;
  final String address;

  /// Only the links that passed SocialLink.sanitize.
  final Map<SocialNetwork, Uri> social;

  factory SupportContact.fromMap(Map<String, dynamic>? data) {
    throw UnimplementedError('G3: SupportContact.fromMap');
  }

  /// Never throws: offline, refused or missing all give [empty].
  static Future<SupportContact> load([FirebaseFirestore? db]) {
    throw UnimplementedError('G3: SupportContact.load');
  }

  bool get hasContactRows => email.isNotEmpty || phone.isNotEmpty || whatsapp.isNotEmpty || address.isNotEmpty;

  /// The set links in [SocialNetwork] order (the footer's icon order).
  List<MapEntry<SocialNetwork, Uri>> get socialLinks {
    throw UnimplementedError('G3: SupportContact.socialLinks');
  }
}
