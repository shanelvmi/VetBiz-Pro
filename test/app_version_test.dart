import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/config/app_info.dart';
import 'package:vetbiz_pro/utils/app_version.dart';

// P1: the minimum app version gate compares dotted numbers, not text.
void main() {
  test('equal is not below', () {
    expect(AppVersion.isBelowMinimum('1.0.0', '1.0.0'), isFalse);
    expect(AppVersion.isBelowMinimum('1.0.0', '1.0'), isFalse);
  });

  test('lower is below', () {
    expect(AppVersion.isBelowMinimum('1.0.0', '1.0.1'), isTrue);
    expect(AppVersion.isBelowMinimum('1.0.0', '2.0.0'), isTrue);
    expect(AppVersion.isBelowMinimum('1.2.3', ' 1.3 '), isTrue);
  });

  test('higher is not below', () {
    expect(AppVersion.isBelowMinimum('1.0.1', '1.0.0'), isFalse);
    expect(AppVersion.isBelowMinimum('2.0.0', '1.99.99'), isFalse);
  });

  test('1.10.0 is higher than 1.9.0', () {
    expect(AppVersion.isBelowMinimum('1.9.0', '1.10.0'), isTrue);
    expect(AppVersion.isBelowMinimum('1.10.0', '1.9.0'), isFalse);
    expect(AppVersion.compare([1, 10, 0], [1, 9, 0]), greaterThan(0));
  });

  test('an absent minimum never blocks', () {
    expect(AppVersion.isBelowMinimum('1.0.0', null), isFalse);
  });

  test('garbage never blocks', () {
    for (final v in <Object?>['', 'abc', 'v2.0.0', '2.0.0-beta', '2..0', '2.0.', 2, 2.5, true, <String>['9']]) {
      expect(AppVersion.isBelowMinimum('1.0.0', v), isFalse, reason: '$v');
    }
  });

  test("the app's own version is a version", () {
    expect(AppVersion.parse(AppInfo.version), isNotNull);
  });
}
