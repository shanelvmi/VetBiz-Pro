import 'dart:io';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_rules.dart';
import 'package:vetbiz_pro/l10n/l10n.dart';
import 'package:vetbiz_pro/services/membership_service.dart';

class _FunctionsError extends FirebaseFunctionsException {
  _FunctionsError(String code, String message) : super(code: code, message: message);
}

// P1: the account-created sign-in message moved into the ARB, and the
// invite-code rate limit's refusal is worded by the app.
void main() {
  final en = lookupAppLocalizations(const Locale('en'));
  final membershipJs = File('functions/membership.js').readAsStringSync();

  test('the account-created message reads as given, through L10n.current', () {
    expect(en.register_accountCreatedSignIn,
        'Your account was created, but we could not sign you in automatically. Please sign in with your email and password.');
    final src = File('lib/services/auth_service.dart').readAsStringSync();
    expect(src.contains('AccountCreatedException(L10n.current.register_accountCreatedSignIn)'), isTrue);
    expect(src.contains('Please log in'), isFalse);
  });

  test('resource-exhausted (too many wrong invite codes) shows the ARB sentence', () {
    expect(MembershipService.errorMessage(_FunctionsError('resource-exhausted', 'server text')),
        'Too many wrong invite codes. Wait 15 minutes and try again.');
  });

  test("the app's window equals the server's, and so does the English", () {
    final ms = RegExp(r'const INVITE_ATTEMPT_WINDOW_MS = (\d+) \* 60 \* 1000;').firstMatch(membershipJs);
    expect(ms, isNotNull);
    expect(int.parse(ms!.group(1)!), AppRules.inviteAttemptWindowMinutes);
    final message = RegExp(r'const TOO_MANY_INVITE_ATTEMPTS_MESSAGE = "([^"]+)";').firstMatch(membershipJs);
    expect(message!.group(1), en.membership_tooManyInviteAttempts(AppRules.inviteAttemptWindowMinutes));
  });
}
