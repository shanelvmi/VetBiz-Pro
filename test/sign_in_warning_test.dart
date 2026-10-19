import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/l10n/app_localizations.dart';
import 'package:vetbiz_pro/services/membership_service.dart';

// E4b2: after deactivating or removing an assistant the server reports what it
// did to their sign-in (C2). When it saved the change but Firebase Auth
// refused ("failed"), the admin must be told: the person may still be signed in.
void main() {
  const english =
      'The assistant was deactivated, but their sign-in could not be switched off. Reactivate and deactivate again.';

  test('signInFailed is the word the server sends', () {
    expect(MembershipService.signInFailed, 'failed');
    final server = File('functions/membership.js').readAsStringSync();
    expect(server, contains('return "failed";'));
  });

  test('the warning: the exact English, and a Kiswahili draft', () {
    expect(lookupAppLocalizations(const Locale('en')).team_signInSwitchFailed, english);
    expect(lookupAppLocalizations(const Locale('sw')).team_signInSwitchFailed, isNot(english));
    final sw = File('lib/l10n/app_sw.arb').readAsStringSync();
    expect(sw, contains('"@team_signInSwitchFailed": {"x-review":"draft"}'));
  });

  test('every caller of setAssistantStatus and removeAssistantFromFacility reads signIn and warns', () {
    final callers = <String>[];
    final call = RegExp(r'\.(setAssistantStatus|removeAssistantFromFacility)\(');
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.endsWith('membership_service.dart')) continue;
      final src = f.readAsStringSync();
      final lines = src.split('\n');
      for (final line in lines.where(call.hasMatch)) {
        callers.add(f.path);
        expect(line, contains('final signIn = await MembershipService()'), reason: '${f.path}: $line');
      }
      if (call.hasMatch(src)) {
        expect(src, contains('signIn == MembershipService.signInFailed'), reason: f.path);
        expect(src, contains('AppFeedback.warning(L10n.current.team_signInSwitchFailed)'), reason: f.path);
      }
    }
    expect(callers.length, 2, reason: 'expected the two Team Members calls, found $callers');
  });
}
