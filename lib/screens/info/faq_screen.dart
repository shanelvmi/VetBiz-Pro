import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Stub (G4 tests first).
class FaqScreen extends StatelessWidget {
  const FaqScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.authFooter_faq)));
}
