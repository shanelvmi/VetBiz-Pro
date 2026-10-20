import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/l10n_arb.dart';

// R4, decision D9: the app says "Sign in" and "Sign out". The retired
// spellings (Login, Log in, Log into, Logout, Log out, logged in) must not
// come back into any English text. Key names and descriptions are not shown,
// so only the values are checked.
void main() {
  final en = Arb.read(Arb.fileFor(Directory.current, 'en'));
  final retired = RegExp(r'\blog(?:ged|ging)?[ -]?(?:in|into|out)\b|\blogin\b|\blogout\b', caseSensitive: false);

  test('no English text uses Login, Log in, Logout or Log out', () {
    final found = [
      for (final e in en.values.entries)
        if (retired.hasMatch(e.value)) '${e.key}: ${e.value}',
    ];
    expect(found, isEmpty);
  });

  test('the sign-in and sign-out texts read as decided', () {
    expect(en.values['login_loginButton'], 'Sign in');
    expect(en.values['common_logIn'], 'Sign in');
    expect(en.values['common_logout'], 'Sign out');
    expect(en.values['common_signOut'], 'Sign out');
    expect(en.values['facilityPicker_logOut'], 'Sign out');
    expect(en.values['products_statusAll'], 'All Statuses');
  });
}
