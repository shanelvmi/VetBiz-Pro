import 'package:flutter/material.dart';

import '../../config/app_info.dart';
import '../../l10n/l10n.dart';
import '../../models/support_contact.dart';

/// Stub (G4 tests first).
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key, required this.contact});

  final Future<SupportContact> contact;

  @override
  Widget build(BuildContext context) => Scaffold(appBar: AppBar(title: Text(context.l10n.authFooter_about(AppInfo.name))));
}
