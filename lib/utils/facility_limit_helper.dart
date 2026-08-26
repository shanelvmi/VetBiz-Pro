import 'package:cloud_firestore/cloud_firestore.dart';

/// Default cap on how many facilities a single Admin account can
/// create, used only until a Platform Admin configures a different
/// value via Platform Settings (platform_config/settings). Must match
/// the fallback used in firestore.rules' isUnderFacilityLimit() - the
/// rule is the actual enforcement, this is just what the UI shows
/// before that read completes.
const int kDefaultMaxFacilitiesPerAdmin = 6;

/// Reads the currently configured facility limit, or the default if
/// none has been set yet. Falls back to the default on any read
/// failure (e.g. offline) - the Add Facility flow should never be
/// blocked just because this specific read had trouble.
Future<int> loadMaxFacilitiesPerAdmin() async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('platform_config').doc('settings').get();
    final configured = (doc.data()?['maxFacilitiesPerAdmin'] as num?)?.toInt();
    return (configured != null && configured > 0) ? configured : kDefaultMaxFacilitiesPerAdmin;
  } catch (_) {
    return kDefaultMaxFacilitiesPerAdmin;
  }
}

/// Same value as loadMaxFacilitiesPerAdmin(), but live - a Platform
/// Admin lowering or raising the limit while someone already has the
/// registration screen open should be reflected immediately, not
/// require closing and reopening it, matching how subscription
/// pricing already works.
Stream<int> streamMaxFacilitiesPerAdmin() {
  return FirebaseFirestore.instance
      .collection('platform_config')
      .doc('settings')
      .snapshots()
      .map((doc) {
    final configured = (doc.data()?['maxFacilitiesPerAdmin'] as num?)?.toInt();
    return (configured != null && configured > 0) ? configured : kDefaultMaxFacilitiesPerAdmin;
  }).handleError((_) {
    // Same reasoning as streamSubscriptionPlans()'s handleError - a
    // transient read error shouldn't surface as a visible error state
    // over what's otherwise just a quota number.
  });
}
