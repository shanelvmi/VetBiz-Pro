import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:vetbiz_pro/l10n/l10n.dart';

/// One support contact with every Help dialog row set (G3), and the texts
/// the dialog shows for it, in order. Both entry points (the dashboard's
/// Help and the footer's Help and contact) are compared with these.
const helpDialogContact = <String, Object>{
  'email': 'help@vetbiz.co.tz',
  'phone': '+255 700 111 222',
  'whatsapp': '+255 700 333 444',
  'address': 'Plot 7, Arusha',
};

List<String> get helpDialogExpectedRows {
  final l10n = lookupAppLocalizations(const Locale('en'));
  return [
    l10n.dashboard_contactSupport,
    l10n.dashboard_supportIntro('VetBiz Pro'),
    'help@vetbiz.co.tz',
    '+255 700 111 222',
    '+255 700 333 444',
    l10n.debtors_viaWhatsApp,
    'Plot 7, Arusha',
    l10n.common_close,
  ];
}

/// Every text inside the open dialog, top to bottom.
List<String> helpDialogTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.descendant(of: find.byType(AlertDialog), matching: find.byType(Text)))
    .map((t) => t.data ?? '')
    .toList();
