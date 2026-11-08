import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';

import 'helpers/register_harness.dart';
import 'helpers/screen_size_matrix.dart';

// FIN1, written before the change: the flat phone register wizard at
// 360x740, 390x844 and 740x360 (a phone turned sideways), in Light, Dark and
// Kiswahili, on every step of the owner and the assistant flows: no
// overflow, no bright box in Dark, 48 px tap targets and no text under 12 px
// (the size matrix's checks).
const _skip = false;

const _sizes = [Size(360, 740), Size(390, 844), Size(740, 360)];

void main() {
  for (final size in _sizes) {
    for (final look in MatrixLook.values) {
      for (final assistant in [false, true]) {
        for (final step in [1, 2, 3, 4, 5]) {
          final where = '${size.width.toInt()}x${size.height.toInt()} ${look.name} ${assistant ? 'assistant' : 'owner'} step $step';
          testWidgets(where, (tester) async {
            final locale = Locale(look == MatrixLook.kiswahili ? 'sw' : 'en');
            final l10n = lookupAppLocalizations(locale);
            await pumpRegister(
              tester,
              size: size,
              brightness: look == MatrixLook.dark ? Brightness.dark : Brightness.light,
              locale: locale,
              chooseOwner: !assistant,
            );
            await (assistant ? toAssistantStep(tester, step, l10n) : toOwnerStep(tester, step, l10n));
            await checkCase(tester, phone: true, where: 'register $where');
            await finishRegister(tester);
          }, skip: _skip);
        }
      }
    }
  }
}
