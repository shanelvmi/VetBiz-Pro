import 'package:flutter/material.dart';

import '../../l10n/l10n.dart';
import '../../utils/subscription_guard.dart';
import 'record_sheet.dart';

/// HUB1: every tile of the phone hub's action panel (the engine lands next;
/// this is its shape, for the tests committed first).
enum HubTile {
  recordSale,
  recordVisit,
  recordPayment,
  addClient,
  recordTransaction,
  addProduct,
  addBatch,
  sales,
  products,
  services,
  clients,
  debtors,
  payments,
  transactions,
  stockStore,
  reports,
  insights,
  platformAdmin,
}

enum HubGroup { record, dailyWork, business }

const hubCollapsedTiles = <HubTile>[];

bool hubTileAllowed(HubTile tile, {required bool isAdmin, bool isPlatformAdmin = false}) => throw UnimplementedError();

List<HubTile> hubCollapsedTilesFor({required bool isAdmin}) => throw UnimplementedError();

List<({HubGroup group, List<HubTile> tiles})> hubGroupsFor({required bool isAdmin, bool isPlatformAdmin = false}) =>
    throw UnimplementedError();

RecordAction? hubTileAction(HubTile tile) => null;

String hubGroupTitle(AppLocalizations l10n, HubGroup group) => throw UnimplementedError();

String hubTileLabel(AppLocalizations l10n, HubTile tile) => throw UnimplementedError();

IconData hubTileIcon(HubTile tile) => throw UnimplementedError();

bool hubTileMatches(AppLocalizations shown, HubTile tile, String query) => throw UnimplementedError();

Future<void> openHubPlace(BuildContext context, HubTile tile) => throw UnimplementedError();

Future<void> runHubTile(
  BuildContext context,
  HubTile tile, {
  RecordSheetActions? actions,
  RecordGuard guard = navigateOrShowLockedDialog,
  Future<void> Function(BuildContext context, HubTile tile) openPlace = openHubPlace,
  VoidCallback? onDone,
}) =>
    throw UnimplementedError();
