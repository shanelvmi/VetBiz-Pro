// PH4 and UI5: the phone home under its top bar with stand-in actions, and
// the seed data its tests share.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/debt.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
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

/// UI5: three kinds need attention (the strip shows the first and "+2").
const ph4SomeAttention = [
  AttentionItem(AttentionKind.outOfStock, 3),
  AttentionItem(AttentionKind.overdueDebts, 4),
  AttentionItem(AttentionKind.expiringSoon, 2),
];

/// The greeting line as the dashboard builds it ("Good afternoon, Mr. ...").
final ph4Greeting = 'Good afternoon, Mr. ${matrixLongClientName.split(' ').first}';

/// The phone home under its top bar (UI5: the facility name over the
/// greeting, the bell, no Help), as the shell shows it. With [gate] (RV1),
/// inside its ScreenReveal with its skeleton, as the dashboard builds it;
/// [attentionReady] is Needs attention's late slot.
Widget phoneHomeHarness({
  RevealGate? gate,
  bool attentionReady = true,
  PhoneHomeFigures figures = ph4BigFigures,
  bool isAdmin = true,
  String period = 'Today',
  String periodLabel = 'Mon 9 Nov',
  String facilityName = matrixLongFacilityName,
  ValueChanged<String>? onPeriodChanged,
  List<AttentionItem> attention = ph4SomeAttention,
  Future<void> Function(BuildContext, HomeTile)? onTile,
  void Function(BuildContext)? onAttention,
  VoidCallback? onAllDetails,
  bool amountsHidden = false,
  VoidCallback? onToggleAmounts,
}) =>
    Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: PhoneHomeTopBar(
          facilityName: facilityName,
          greeting: ph4Greeting,
          name: matrixLongClientName,
          avatarUrl: null,
          onAvatar: () {},
        ),
        actions: [IconButton(onPressed: () {}, tooltip: 'Notifications', icon: const Icon(Icons.notifications_none))],
      ),
      body: Builder(builder: (context) {
        PhoneHome home({bool skeleton = false}) => PhoneHome(
              skeleton: skeleton,
              attentionReady: attentionReady,
              figures: figures,
              isAdmin: isAdmin,
              period: period,
              periodLabel: periodLabel,
              onPeriodChanged: onPeriodChanged ?? (_) {},
              attention: attention,
              onAllDetails: onAllDetails ?? () {},
              onTile: (t) => (onTile ?? (_, __) async {})(context, t),
              onAttention: () => onAttention?.call(context),
              amountsHidden: amountsHidden,
              onToggleAmounts: onToggleAmounts ?? () {},
            );
        return gate == null ? home() : ScreenReveal(gate: gate, skeleton: home(skeleton: true), child: home());
      }),
    );

Future<void> pumpPhoneHome(WidgetTester tester, Widget screen, {Size size = const Size(390, 844)}) =>
    pumpAtSize(tester, screen: screen, size: size);

/// Every text drawn.
List<String> drawnTexts(WidgetTester tester) =>
    find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toList();
