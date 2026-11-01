import 'package:flutter/material.dart';

import 'dashboard_figures.dart';

// PH4 stub: the API the tests are written against; implemented next.

class TodayCard extends StatelessWidget {
  final PhoneHomeFigures figures;
  final bool isAdmin;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final VoidCallback onAllDetails;

  const TodayCard({
    super.key,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.onAllDetails,
  });

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
