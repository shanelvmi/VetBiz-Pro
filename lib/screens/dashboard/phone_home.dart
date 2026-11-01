import 'package:flutter/material.dart';

import 'dashboard_figures.dart';
import 'needs_attention.dart';
import 'phone_home_rows.dart';
import 'record_sheet.dart';

export 'dashboard_figures.dart';
export 'phone_home_rows.dart' show GoToItem, goToItemsFor, goToMoreItem, goToLabel;
export 'today_card.dart' show TodayCard;

// PH4 stub: the API the tests are written against; implemented next.

class PhoneHomeTopBar extends StatelessWidget {
  final String greeting;
  final String name;
  final String? avatarUrl;
  final VoidCallback onAvatar;

  const PhoneHomeTopBar(
      {super.key, required this.greeting, required this.name, required this.avatarUrl, required this.onAvatar});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class PhoneHome extends StatelessWidget {
  final PhoneHomeFigures figures;
  final bool isAdmin;
  final String period;
  final ValueChanged<String> onPeriodChanged;
  final AttentionCounts attention;
  final VoidCallback onAllDetails;
  final Future<void> Function(RecordAction action) onQuickAction;
  final VoidCallback onViewAll;
  final ValueChanged<GoToItem> onGoTo;
  final ValueChanged<AttentionTarget> onAttention;
  final Widget? overlay;

  const PhoneHome({
    super.key,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.attention,
    required this.onAllDetails,
    required this.onQuickAction,
    required this.onViewAll,
    required this.onGoTo,
    required this.onAttention,
    this.overlay,
  });

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
