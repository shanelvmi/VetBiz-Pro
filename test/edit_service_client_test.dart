// E4d-3 (1): Edit Service starts with the service's own client. The form
// never set it, so its client validator refused an unchanged edit until the
// client was picked again (add_edit_service_screen.dart).
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/screens/services/add_edit_service_screen.dart';

import 'helpers/fake_firestore.dart';

void main() {
  test('a service with a client: the form starts with that client (its id is what is saved)', () {
    final client = clientOfEditedService(testService(id: 'v1', clientId: 'c2', clientName: 'Neema'));
    expect([client?.id, client?.name], ['c2', 'Neema']);
  });

  test('a new service, or one with no client: nothing is picked', () {
    expect(clientOfEditedService(null), isNull);
    expect(clientOfEditedService(testService(id: 'v1')), isNull);
  });

  test('the form uses it when it opens', () {
    final source = File('lib/screens/services/add_edit_service_screen.dart').readAsStringSync();
    expect(source, contains('_selectedClient = clientOfEditedService(widget.service);'));
  });
}
