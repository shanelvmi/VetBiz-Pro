import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';

/// Stub (G4 tests first).
class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.authFooter_howToUse)));
}
