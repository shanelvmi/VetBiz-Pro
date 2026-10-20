import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_info.dart';

// R3, D6: one app name, "VetBiz Pro" (legal text and the two-tone wordmark
// excepted), and the version typed once, in AppInfo.
void main() {
  Map<String, dynamic> arb(String lang) =>
      jsonDecode(File('lib/l10n/app_$lang.arb').readAsStringSync()) as Map<String, dynamic>;

  test('the name and the version live in AppInfo', () {
    expect(AppInfo.name, 'VetBiz Pro');
    expect(AppInfo.version, '2.0.0');
    expect(AppInfo.versionLabel, 'v${AppInfo.version}');
  });

  test('the footer reads "© 2026 VetBiz Pro. All rights reserved."', () {
    expect(arb('en')['login_copyright'], '© 2026 {appName}. All rights reserved.');
    expect(arb('sw')['login_copyright'], '© 2026 {appName}. Haki zote zimehifadhiwa.');
    for (final lang in ['en', 'sw']) {
      expect(arb(lang).containsKey('common_appSystem'), isFalse, reason: 'the "VetBiz Pro System" header key is gone');
    }
  });

  test('no screen types a version or "VetBiz Pro System"', () {
    for (final f in Directory('lib').listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart') || f.path.contains('app_localizations')) continue;
      final src = f.readAsStringSync();
      expect(src.contains('VetBiz Pro System'), isFalse, reason: f.path);
      expect(RegExp(r"settings_versionLine\([^)]*'").hasMatch(src), isFalse, reason: '${f.path} types the version');
    }
  });
}
