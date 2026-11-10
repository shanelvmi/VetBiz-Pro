// PH4 and UI5: the phone home under its top bar with stand-in actions, and
// the seed data its tests share.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vetbiz_pro/models/debt.dart';
import 'package:vetbiz_pro/models/product.dart';
import 'package:vetbiz_pro/screens/dashboard/needs_attention.dart';
import 'package:vetbiz_pro/screens/dashboard/home_chart_carousel.dart';
import 'package:vetbiz_pro/screens/dashboard/home_action_panel.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_home.dart';
import 'package:vetbiz_pro/screens/dashboard/phone_hub.dart';
import 'package:vetbiz_pro/services/home_chart_data.dart';
import 'package:vetbiz_pro/services/insights_data_loader.dart';
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
/// greeting, the bell, no Help) with the action panel docked over its bottom,
/// as the hub shows it (HUB1). With [gate] (RV1),
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
  Future<void> Function(BuildContext, HubTile)? onTile,
  void Function(BuildContext)? onAttention,
  VoidCallback? onAllDetails,
  bool amountsHidden = false,
  VoidCallback? onToggleAmounts,
  Widget? charts,
}) =>
    PhoneHub(
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
      panel: Builder(
        builder: (context) => HomeActionPanel(isAdmin: isAdmin, onTile: (t) => (onTile ?? (_, __) async {})(context, t)),
      ),
      home: (context) {
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
              onAttention: () => onAttention?.call(context),
              amountsHidden: amountsHidden,
              onToggleAmounts: onToggleAmounts ?? () {},
              charts: charts,
            );
        return gate == null ? home() : ScreenReveal(gate: gate, skeleton: home(skeleton: true), child: home());
      },
    );

Future<void> pumpPhoneHome(WidgetTester tester, Widget screen, {Size size = const Size(390, 844)}) =>
    pumpAtSize(tester, screen: screen, size: size);

/// Every text drawn.
List<String> drawnTexts(WidgetTester tester) =>
    find.byType(RichText).evaluate().map((e) => (e.widget as RichText).text.toPlainText()).toList();

/// HUB2: the chart carousel with fixed data (answered at once), as Home
/// builds it, counting what it asks for.
class HarnessCharts {
  int days = 0, products = 0, opened = 0;

  Widget build({bool hidden = false}) => HomeChartCarousel(
        days: () {
          days++;
          final today = DateTime(ph4Now.year, ph4Now.month, ph4Now.day);
          return Future.value(HomeChartDays(
            firstDay: today.subtract(const Duration(days: 13)),
            sales: [for (var i = 0; i < 14; i++) matrixBigAmount / (i + 1)],
            services: [for (var i = 0; i < 14; i++) i.isEven ? matrixBigAmount / 10 : 0],
          ));
        },
        products: () {
          products++;
          return Future.value(const [ProductMovement(matrixLongProductName, 12345678), ProductMovement('Dewormer', 8)]);
        },
        amountsHidden: hidden,
        onOpen: () => opened++,
      );
}
