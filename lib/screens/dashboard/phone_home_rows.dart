import 'package:flutter/material.dart';

import 'more_screen.dart';
import 'record_sheet.dart';

// PH4 stub: the API the tests are written against; implemented next.

enum GoToItem { products, clients, debtors, reports, transactions, stockStore, services, payments }

List<GoToItem> goToItemsFor({required bool isAdmin}) => throw UnimplementedError();

MoreItem? goToMoreItem(GoToItem item) => throw UnimplementedError();

String goToLabel(BuildContext context, GoToItem item) => throw UnimplementedError();

class QuickAccessTiles extends StatelessWidget {
  final Future<void> Function(RecordAction action) onAction;

  const QuickAccessTiles({super.key, required this.onAction});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}

class GoToRow extends StatelessWidget {
  final List<GoToItem> items;
  final ValueChanged<GoToItem> onGoTo;

  const GoToRow({super.key, required this.items, required this.onGoTo});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
