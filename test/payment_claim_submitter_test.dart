// E4d-3 (4), C11: a subscription payment claim names its submitter twice:
// submittedBy (the email, kept for people to read) and submittedById (the
// uid firestore.rules checks against request.auth.uid).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/subscription/subscription_screen.dart';

void main() {
  test('the claim keeps the email for display and adds the uid', () {
    expect(paymentClaimSubmitter(email: 'neema@example.com', uid: 'u1'),
        {'submittedBy': 'neema@example.com', 'submittedById': 'u1', 'submittedByName': 'neema@example.com'});
  });

  test('an account with no email: the uid in both, as submittedBy was before', () {
    expect(paymentClaimSubmitter(uid: 'u1'), {'submittedBy': 'u1', 'submittedById': 'u1', 'submittedByName': 'u1'});
  });

  test("SUBS-1: with the profile's full name, that is the name stored", () {
    expect(paymentClaimSubmitter(email: 'neema@example.com', uid: 'u1', fullName: ' Neema Mushi ')['submittedByName'],
        'Neema Mushi');
  });

  test('the claim the screen submits uses it', () {
    final source = File('lib/screens/subscription/subscription_screen.dart').readAsStringSync();
    expect(source, contains('...paymentClaimSubmitter(email: user?.email, uid: user?.uid, fullName: fullName),'));
    expect(source, isNot(contains("'submittedBy': user")));
  });
}
