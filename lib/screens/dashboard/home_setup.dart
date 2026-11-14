import '../../data/home_setup_state.dart';
import 'hub_destinations.dart';

/// HUB4b: a step of the phone Home's first-time checklist, in its order, with
/// the panel tile that performs it (the same guard and form). "Invite your
/// team" is not a step: nothing held on Home says whether a team member was
/// ever invited (no read is added for it).
enum HomeSetupStep {
  addProduct(HubTile.addProduct),
  addClient(HubTile.addClient),
  recordSale(HubTile.recordSale);

  const HomeSetupStep(this.tile);

  final HubTile tile;
}

/// One step and whether it is done.
class HomeSetupItem {
  final HomeSetupStep step;
  final bool done;

  const HomeSetupItem(this.step, {required this.done});

  @override
  bool operator ==(Object other) => other is HomeSetupItem && other.step == step && other.done == done;

  @override
  int get hashCode => Object.hash(step, done);

  @override
  String toString() => 'HomeSetupItem(${step.name}, done: $done)';
}

/// What Home shows and what the device should remember.
class HomeSetupDecision {
  /// The rows, steps still to do first (each group in step order). Empty:
  /// no card.
  final List<HomeSetupItem> items;

  /// The state to save now, or null to leave the saved one.
  final HomeSetupState? save;

  const HomeSetupDecision({this.items = const [], this.save});

  bool get shows => items.isNotEmpty;
}

/// The checklist from data already held only: [hasProducts] (the products
/// provider), [hasClients] (the clients provider) and [hasSales] (the period
/// totals and the 14-day summary read Home already makes); null = not held
/// yet, and a step without held data is left out. A NEW facility (no
/// products and no sales held) starts it; it stays, progress shown, until
/// every step left is done ([HomeSetupState.done]) or the person hides it.
/// Never with the attention strip: [attentionShown] wins (the state is kept,
/// so the card comes back when the strip goes). An assistant sees only the
/// steps their role may perform (the panel's [hubTileAllowed]).
HomeSetupDecision homeSetupFor({
  required HomeSetupState? saved,
  required bool isAdmin,
  required bool? hasProducts,
  required bool? hasClients,
  required bool? hasSales,
  bool attentionShown = false,
}) {
  if (saved == HomeSetupState.hidden || saved == HomeSetupState.done) return const HomeSetupDecision();
  final held = {
    HomeSetupStep.addProduct: hasProducts,
    HomeSetupStep.addClient: hasClients,
    HomeSetupStep.recordSale: hasSales,
  };
  final items = [
    for (final step in HomeSetupStep.values)
      if (hubTileAllowed(step.tile, isAdmin: isAdmin) && held[step] != null) HomeSetupItem(step, done: held[step]!),
  ];
  // Only a facility known to be new starts it; until both are held, nothing
  // is decided.
  if (saved == null && (hasProducts != false || hasSales != false)) return const HomeSetupDecision();
  final start = saved == null ? HomeSetupState.started : null;
  if (items.isEmpty) return HomeSetupDecision(save: start);
  if (items.every((i) => i.done)) return const HomeSetupDecision(save: HomeSetupState.done);
  if (attentionShown) return HomeSetupDecision(save: start);
  return HomeSetupDecision(
    items: [...items.where((i) => !i.done), ...items.where((i) => i.done)],
    save: start,
  );
}
