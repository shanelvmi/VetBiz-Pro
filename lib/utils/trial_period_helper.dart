import 'package:cloud_firestore/cloud_firestore.dart';

import '../constants/subscription_plans.dart';

/// Looks up the Platform Admin's configured trial length
/// (platform_config/settings.trialDays) and returns the expiry date a
/// brand-new facility's trial should end on. Falls back to
/// kDefaultTrialDays if no config document exists yet, or the read
/// fails for any reason - a facility should never fail to be created
/// just because a config lookup had trouble.
///
/// Deliberately only ever called at facility-creation time, not
/// retroactively applied to existing facilities - changing the
/// configured length only ever affects facilities created after that
/// change, never ones already mid-trial.
Future<DateTime> computeNewFacilityTrialExpiry() async {
  int days = kDefaultTrialDays;
  try {
    final configDoc =
        await FirebaseFirestore.instance.collection('platform_config').doc('settings').get();
    final configuredDays = (configDoc.data()?['trialDays'] as num?)?.toInt();
    if (configuredDays != null && configuredDays > 0) {
      days = configuredDays;
    }
  } catch (_) {
    // Config lookup failed - proceed with the default rather than
    // blocking facility creation over it.
  }
  final expiryDate = DateTime.now().add(Duration(days: days));
  return DateTime(expiryDate.year, expiryDate.month, expiryDate.day, 23, 59, 59);
}
