// POL6 (owner answer 1): one function each maps a debt's and a client's
// standing to one of the four states, keeping today's words and threshold:
// a debt is Overdue (danger) past the overdue days, else Current (neutral,
// the normal case); a client's stored status, Active or Inactive, is
// neutral either way (the word tells them apart). Payments reuse
// paymentAppStatus. The stored values never change.
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/ui/polish/app_status.dart';

void main() {
  test('debtAppStatus: overdue danger, current neutral', () {
    expect(debtAppStatus(isOverdue: true), AppStatus.danger);
    expect(debtAppStatus(isOverdue: false), AppStatus.neutral);
  });

  test('clientAppStatus: the stored Active and Inactive are neutral; so is anything else', () {
    for (final stored in ['Active', 'Inactive', '', 'active', 'Archived']) {
      expect(clientAppStatus(stored), AppStatus.neutral, reason: stored);
    }
  });
}
