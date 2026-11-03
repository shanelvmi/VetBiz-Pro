import 'package:flutter/material.dart';

import '../../theme/app_dimens.dart';
import '../../theme/app_text.dart';
import '../../theme/theme_context.dart';

// PH7b R1 (docs/design/phone_reports.md): a report's tabs on a phone, one
// sideways-scrolling bar from the left edge, labels at 14 and tabs 48 high.
// A scrollable TabBar scrolls the selected tab into view by itself, after a
// tap and after a swipe of the pages.

class PhoneReportTabBar extends StatelessWidget {
  final TabController controller;
  final List<String> labels;

  const PhoneReportTabBar({super.key, required this.controller, required this.labels});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    const label = TextStyle(fontSize: PhoneReportMetrics.tabLabel, fontWeight: AppFontWeight.semibold);
    return Material(
      key: const ValueKey('phoneReport-tabBar'),
      color: colors.surface,
      child: TabBar(
        controller: controller,
        isScrollable: true,
        tabAlignment: TabAlignment.start,
        labelColor: colors.primary,
        unselectedLabelColor: colors.textMuted,
        indicatorColor: colors.primary,
        labelStyle: label,
        unselectedLabelStyle: label.copyWith(fontWeight: AppFontWeight.medium),
        tabs: [for (final l in labels) Tab(height: PhoneReportMetrics.tabHeight, text: l)],
      ),
    );
  }
}
