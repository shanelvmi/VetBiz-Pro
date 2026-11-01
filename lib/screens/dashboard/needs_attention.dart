import 'package:flutter/material.dart';

import '../../models/debt.dart';
import '../../models/product.dart';

// PH4 stub: the API the tests are written against; implemented next.

enum AttentionTarget { stockAlerts, debtors }

class AttentionCounts {
  final int stock;
  final int expiry;
  final int overdueDebtors;
  final int overdueDays;

  const AttentionCounts({this.stock = 0, this.expiry = 0, this.overdueDebtors = 0, this.overdueDays = 30});

  bool get isEmpty => throw UnimplementedError();
}

AttentionCounts attentionCountsFor(
        {required List<Product> products, required List<Debt> debts, required int overdueDays, DateTime? now}) =>
    throw UnimplementedError();

class NeedsAttentionStrip extends StatelessWidget {
  final AttentionCounts counts;
  final ValueChanged<AttentionTarget> onOpen;

  const NeedsAttentionStrip({super.key, required this.counts, required this.onOpen});

  @override
  Widget build(BuildContext context) => throw UnimplementedError();
}
