// E4d-3 (4), C11: a subscription payment claim names its submitter twice:
// submittedBy (the email, kept for people to read) and submittedById (the
// uid firestore.rules checks against request.auth.uid).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';

void main() {
  test('the claim keeps the email for display and adds the uid', () {
    expect(paymentClaimSubmitter(email: 'neema@example.com', uid: 'u1'),
        {'submittedBy': 'neema@example.com', 'submittedById': 'u1'});
  });

  test('an account with no email: the uid in both, as submittedBy was before', () {
    expect(paymentClaimSubmitter(uid: 'u1'), {'submittedBy': 'u1', 'submittedById': 'u1'});
  });

  test('the claim the screen submits uses it', () {
    final source = File('lib/screens/subscription/subscription_screen.dart').readAsStringSync();
    expect(source, contains('...paymentClaimSubmitter(email: user?.email, uid: user?.uid),'));
    expect(source, isNot(contains("'submittedBy': user")));
  });
}
