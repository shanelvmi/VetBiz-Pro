import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/register_harness.dart';

// RW2c, before the change: today's one-page assistant form, driven with the
// fixed inputs of AssistantInputs, sends exactly this call. The wizard must
// send the same (rw2c_assistant_wizard_test.dart asserts it). This file is
// removed with the old form.
void main() {
  final en = registerEn;

  testWidgets('the old assistant form\'s call for the fixed inputs', (tester) async {
    final auth = FakeRegisterAuth();
    final membership = FakeRegisterMembership();
    await pumpRegister(tester, auth: auth, membership: membership);
    await tapText(tester, en.register_roleAssistantSubtitle);
    await tapContinue(tester);

    Finder field(String hint) => find.widgetWithText(TextField, hint);
    await tester.tap(find.byType(DropdownButtonFormField<String>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text(AssistantInputs.prefix).last);
    await tester.pumpAndSettle();
    await tester.enterText(field(en.register_enterFullName), AssistantInputs.name);
    await tester.enterText(field(en.register_emailHint), AssistantInputs.email);
    await tester.enterText(field(en.register_phoneHint), AssistantInputs.phone);
    await tester.enterText(field(en.register_enterInviteCode), AssistantInputs.code);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    await tester.enterText(field(en.register_createPassword), AssistantInputs.password);
    await tester.enterText(field(en.register_reenterPassword), AssistantInputs.password);
    await tester.pump();
    await tapText(tester, en.register_createAccount);

    expect(membership.checked, [AssistantInputs.code.trim()]);
    expect(auth.assistantCalls, [AssistantInputs.recordedCall]);
    await finishRegister(tester);
  });
}
