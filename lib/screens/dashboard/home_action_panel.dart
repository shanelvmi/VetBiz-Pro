import 'package:flutter/material.dart';

import 'hub_destinations.dart';

/// HUB1: the action panel docked at the bottom of the phone Home (it lands
/// next; this is its shape, for the tests committed first).
class HomeActionPanel extends StatelessWidget {
  final bool isAdmin;
  final bool isPlatformAdmin;
  final Future<void> Function(HubTile tile) onTile;

  const HomeActionPanel({super.key, required this.isAdmin, this.isPlatformAdmin = false, required this.onTile});

  static double collapsedHeightOf(BuildContext context) => 0;

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
