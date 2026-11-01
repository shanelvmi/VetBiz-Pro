import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../services/dashboard_summary_service.dart';

// PH4 stub: the API the tests are written against; implemented next.

enum DetailsTarget { products, sales, payments, reports, transactions, debtors, clients, services }

class AllDetailsFigures {
  final DashboardPeriodTotals totals;
  final double productValue;
  final double outstanding;
  final int clients;
  final bool loading;

  const AllDetailsFigures(
      {required this.totals, required this.productValue, required this.outstanding, required this.clients, this.loading = false});
}

class DetailRow {
  final String label;
  final String value;
  final DetailsTarget target;
  final (String, String)? earned;
  final (String, String)? pending;

  const DetailRow(this.label, this.value, this.target, {this.earned, this.pending});
}

List<DetailRow> allDetailRows(AppLocalizations l, AllDetailsFigures f, {required bool isAdmin, required String period}) =>
    throw UnimplementedError();

class AllDetailsScreen extends StatelessWidget {
  final Listenable changes;
  final AllDetailsFigures Function() figures;
  final bool Function() isAdmin;
  final String Function() period;
  final ValueChanged<String> onPeriodChanged;
  final ValueChanged<DetailsTarget> onOpen;
  final WidgetBuilder chart;
  final WidgetBuilder feed;

  const AllDetailsScreen({
    super.key,
    required this.changes,
    required this.figures,
    required this.isAdmin,
    required this.period,
    required this.onPeriodChanged,
    required this.onOpen,
    required this.chart,
    required this.feed,
  });

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
