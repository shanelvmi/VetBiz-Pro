import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../data/collections.dart';
import '../data/support_contact_fields.dart';
import '../utils/social_link.dart';

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
    String text(String key) {
      final value = data?[key];
      return value is String ? value.trim() : '';
    }

    final social = <SocialNetwork, Uri>{};
    for (final network in SocialNetwork.values) {
      final link = SocialLink.sanitize(text(network.field));
      if (link != null && link.isNotEmpty) social[network] = Uri.parse(link);
    }
    return SupportContact(
      email: text(SupportContactFields.email),
      phone: text(SupportContactFields.phone),
      whatsapp: text(SupportContactFields.whatsapp),
      address: text(SupportContactFields.address),
      social: social,
    );
  }

  /// Never throws: offline, refused or missing all give [empty].
  static Future<SupportContact> load([FirebaseFirestore? db]) async {
    try {
      final doc = await (db ?? FirebaseFirestore.instance)
          .collection(Collections.appConfig)
          .doc(SupportContactFields.docId)
          .get();
      return SupportContact.fromMap(doc.data());
    } catch (_) {
      // A failed read must not block anyone: the Help dialog still opens
      // with its generic sentence, and the footer shows no icons.
      return empty;
    }
  }

  /// The public fields as the document stores them (G6: the device's
  /// last-known copy). Read back through [SupportContact.fromMap], so every
  /// link is sanitised again.
  Map<String, String> toMap() => {
        SupportContactFields.email: email,
        SupportContactFields.phone: phone,
        SupportContactFields.whatsapp: whatsapp,
        SupportContactFields.address: address,
        for (final network in SocialNetwork.values) network.field: social[network]?.toString() ?? '',
      };

  @override
  bool operator ==(Object other) =>
      other is SupportContact &&
      other.email == email &&
      other.phone == phone &&
      other.whatsapp == whatsapp &&
      other.address == address &&
      mapEquals(other.social, social);

  @override
  int get hashCode => Object.hash(email, phone, whatsapp, address, Object.hashAllUnordered(social.entries.map((e) => Object.hash(e.key, e.value))));

  bool get hasContactRows => email.isNotEmpty || phone.isNotEmpty || whatsapp.isNotEmpty || address.isNotEmpty;

  /// The set links in [SocialNetwork] order (the footer's icon order).
  List<MapEntry<SocialNetwork, Uri>> get socialLinks => [
        for (final network in SocialNetwork.values)
          if (social[network] case final uri?) MapEntry(network, uri),
      ];
}
