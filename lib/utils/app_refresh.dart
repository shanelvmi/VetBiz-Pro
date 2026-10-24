import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/fields.dart';
import '../l10n/l10n.dart';
import '../providers/facility_provider.dart';
import '../providers/user_role_provider.dart';
import '../ui/feedback/app_feedback.dart';
import 'facility_activation.dart';
import 'force_logout.dart';
import 'navigator_key.dart';

/// System Refresh (UI Settings, REFRESH-1): reloads all of this facility's
/// data from the server and opens its dashboard, still signed in, with no
/// page reload on the web.
///
/// It is the sign-in path itself, run again for the facility already open:
/// activateFacilityAndGoToDashboard resets every provider (their live
/// listeners, cached lists and list pages; provider_reset.dart), wires them
/// up afresh and opens the dashboard, so a refresh can never miss something
/// that signing in reloads. It used to send the person back to the front
/// door (returnToAccountDecision), which re-decided the whole account and
/// left the list pages as they were.
///
/// Kept: the signed-in user, the facility, and the UI settings (language,
/// colour theme, Dark Mode, Layout Fixed Mode), which provider_reset leaves
/// alone.
///
/// The server is asked first, before anything is reset: offline, the person
/// is told why and stays on the screen they were on, with its data.
Future<void> refreshAppData() async {
  final context = navigatorKey.currentContext;
  if (context == null || !context.mounted) return;
  final facility = context.read<FacilityProvider>();
  final facilityId = facility.selectedFacilityId;
  if (facilityId == null) {
    // No facility open (a platform admin's own panel): the front door
    // decides afresh, as before.
    await returnToAccountDecision();
    return;
  }
  final facilityName = facility.selectedFacilityName ?? '';
  final facilityType = facility.selectedFacilityType ?? '';
  final role = context.read<UserRoleProvider>().role;

  final navigator = navigatorKey.currentState!;
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const PopScope(canPop: false, child: Center(child: CircularProgressIndicator())),
  );
  try {
    await facility.checkServerReachable();
  } catch (e, st) {
    navigator.pop();
    AppFeedback.error(L10n.current.uiSettings_refreshFailed, error: e, stackTrace: st);
    return;
  }
  navigator.pop();

  final current = navigatorKey.currentContext;
  if (current == null || !current.mounted) return;
  await activateFacilityAndGoToDashboard(
    context: current,
    facility: {Fields.facilityId: facilityId, 'facilityName': facilityName, 'facilityType': facilityType},
    role: role,
  );
  AppFeedback.success(L10n.current.uiSettings_refreshDone);
}
