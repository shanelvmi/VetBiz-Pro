// PH4: the phone home under its top bar with stand-in actions, and the seed
// data its tests share (ph4_phone_home_test, ph4_quick_go_attention_test).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/debt.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/record_sheet.dart';
import 'package:vetbiz_pro/widgets/reveal/reveal.dart';

import 'screen_size_matrix.dart';

const ph4PhoneSizes = [
  MatrixSize('360x740', Size(360, 740), phone: true),
  MatrixSize('390x844', Size(390, 844), phone: true),
  MatrixSize('740x360', Size(740, 360), phone: true),
];

final ph4Now = DateTime.now();

Product ph4Product(String id, {int qty = 50, int low = 5, DateTime? expiry, bool everStocked = true}) => Product(
      id: id,
      name: id == 'long' ? matrixLongProductName : id,
      buyPrice: 1000,
      sellPrice: 1500,
      stockQty: 0,
      sellableQty: qty,
      unit: 'pcs',
      type: 'Drug',
      category: 'Drugs',
      facilityId: 'f1',
      expiry: expiry,
      lowStockThreshold: low,
      hasEverHadStock: everStocked,
    );

Debt ph4Debt(String client, double owed, int daysAgo) => Debt(
      id: '$client-$daysAgo',
      clientId: client,
      source: 'Sale',
      amountOwed: owed,
      timestamp: ph4Now.subtract(Duration(days: daysAgo)),
      updatedAt: ph4Now,
      items: const [],
    );

const ph4BigFigures = PhoneHomeFigures(
  sales: matrixBigAmount,
  collected: matrixBigAmount,
  owed: matrixBigAmount,
  netProfit: matrixBigAmount,
);

const ph4SomeAttention = AttentionCounts(stock: 3, expiry: 2, overdueDebtors: 4, overdueDays: 30);

/// The phone home under its top bar, as the shell shows it. With [gate]
/// (RV1), inside its ScreenReveal with its skeleton, as the dashboard builds
/// it; [attentionReady] is Needs attention's late slot.
Widget phoneHomeHarness({
  RevealGate? gate,
  bool attentionReady = true,
  PhoneHomeFigures figures = ph4BigFigures,
  bool isAdmin = true,
  String period = 'Today',
  ValueChanged<String>? onPeriodChanged,
  AttentionCounts attention = ph4SomeAttention,
  Future<void> Function(BuildContext, RecordAction)? onQuickAction,
  void Function(BuildContext)? onViewAll,
  ValueChanged<GoToItem>? onGoTo,
  ValueChanged<AttentionTarget>? onAttention,
  VoidCallback? onAllDetails,
}) =>
    Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: PhoneHomeTopBar(
          greeting: 'Good afternoon',
          name: 'Mr. ${matrixLongClientName.split(' ').first}',
          avatarUrl: null,
          onAvatar: () {},
        ),
        actions: [IconButton(onPressed: () {}, tooltip: 'Help', icon: const Icon(Icons.help_outline))],
      ),
      body: Builder(builder: (context) {
        PhoneHome home({bool skeleton = false}) => PhoneHome(
              skeleton: skeleton,
              attentionReady: attentionReady,
              figures: figures,
              isAdmin: isAdmin,
              period: period,
              onPeriodChanged: onPeriodChanged ?? (_) {},
              attention: attention,
              onAllDetails: onAllDetails ?? () {},
              onQuickAction: (a) => (onQuickAction ?? (_, __) async {})(context, a),
              onViewAll: () => onViewAll?.call(context),
              onGoTo: onGoTo ?? (_) {},
              onAttention: onAttention ?? (_) {},
            );
        return gate == null ? home() : ScreenReveal(gate: gate, skeleton: home(skeleton: true), child: home());
      }),
    );

Future<void> pumpPhoneHome(WidgetTester tester, Widget screen, {Size size = const Size(390, 844)}) =>
    pumpAtSize(tester, screen: screen, size: size);

/// Every text drawn.
List<String> drawnTexts(WidgetTester tester) =>
    find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toList();
