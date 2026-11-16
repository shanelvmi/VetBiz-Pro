// HUB4b (2): the phone Home's first-time checklist, from data already held
// only (products, clients, the held sales totals); the device remembers where
// it stands per facility (shared_preferences, never synced).
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vetbiz_pro/data/home_setup_state.dart';
import 'package:vetbiz_pro/providers/ui_settings_provider.dart';
import 'package:vetbiz_pro/screens/dashboard/home_setup.dart';
import 'package:vetbiz_pro/screens/dashboard/hub_destinations.dart';


Future<void> _loaded(UiSettingsProvider ui) async {
  for (var i = 0; !ui.loaded && i < 500; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(ui.loaded, isTrue);
}

final _nothing = predicate<HomeSetupDecision>((d) => !d.shows && d.save == null, 'no card, nothing saved');

const _product = HomeSetupStep.addProduct, _client = HomeSetupStep.addClient, _sale = HomeSetupStep.recordSale;

HomeSetupDecision _for({
  HomeSetupState? saved,
  bool isAdmin = true,
  bool? products = false,
  bool? clients = false,
  bool? sales = false,
  bool attention = false,
}) =>
    homeSetupFor(
      saved: saved,
      isAdmin: isAdmin,
      hasProducts: products,
      hasClients: clients,
      hasSales: sales,
      attentionShown: attention,
    );

void main() {
  group('the stored values', () {
    test('keys and order are pinned', () {
      expect(HomeSetupState.values.map((s) => s.key), ['started', 'hidden', 'done']);
      expect(HomeSetupState.fromKey('hidden'), HomeSetupState.hidden);
      expect(HomeSetupState.fromKey('nonsense'), isNull);
      expect(HomeSetupState.fromKey(null), isNull);
      expect(UiSettingsProvider.homeSetupKeyPrefix, 'ui_home_setup_');
    });

    test('the steps, their order and the panel tiles they run (no Invite your team: nothing held says it)', () {
      expect(HomeSetupStep.values, [_product, _client, _sale]);
      expect(HomeSetupStep.values.map((s) => s.tile), [HubTile.addProduct, HubTile.addClient, HubTile.recordSale]);
    });
  });

  group('the decision', () {
    test('a new facility: every step to do, and it is remembered as started', () {
      final d = _for();
      expect(d.items, const [
        HomeSetupItem(_product, done: false),
        HomeSetupItem(_client, done: false),
        HomeSetupItem(_sale, done: false),
      ]);
      expect(d.save, HomeSetupState.started);
    });

    test('not new (products or sales held) and never started: no card, nothing saved', () {
      expect(_for(products: true).shows, isFalse);
      expect(_for(sales: true).shows, isFalse);
      expect(_for(products: true).save, isNull);
    });

    test('nothing decided until products and sales are both held', () {
      expect(_for(products: null), _nothing);
      expect(_for(sales: null), _nothing);
    });

    test('partly done: steps to do first, then the done ones; nothing new saved', () {
      final d = _for(saved: HomeSetupState.started, products: true, clients: true);
      expect(d.items, const [
        HomeSetupItem(_sale, done: false),
        HomeSetupItem(_product, done: true),
        HomeSetupItem(_client, done: true),
      ]);
      expect(d.save, isNull);
    });

    test('all done: no card, remembered as done', () {
      final d = _for(saved: HomeSetupState.started, products: true, clients: true, sales: true);
      expect(d.shows, isFalse);
      expect(d.save, HomeSetupState.done);
    });

    test('hidden or done: never again, whatever the data', () {
      for (final s in [HomeSetupState.hidden, HomeSetupState.done]) {
        expect(_for(saved: s).shows, isFalse);
        expect(_for(saved: s).save, isNull);
      }
    });

    test('the strip wins: no card while it shows, the start still remembered', () {
      final d = _for(attention: true);
      expect(d.shows, isFalse);
      expect(d.save, HomeSetupState.started);
      expect(_for(saved: HomeSetupState.started, attention: true).save, isNull);
    });

    test('an assistant: only the steps they may perform (no Add product)', () {
      final d = _for(isAdmin: false);
      expect(d.items.map((i) => i.step), [_client, _sale]);
      expect(_for(isAdmin: false, saved: HomeSetupState.started, products: true, clients: true, sales: true).save,
          HomeSetupState.done);
    });

    test('a step without held data is left out', () {
      final d = _for(saved: HomeSetupState.started, clients: null);
      expect(d.items.map((i) => i.step), [_product, _sale]);
    });
  });

  group('the device memory', () {
    test('saved per facility, read back by a new provider', () async {
      SharedPreferences.setMockInitialValues({});
      final first = UiSettingsProvider();
      await _loaded(first);
      await first.setHomeSetupState('f1', HomeSetupState.hidden, notify: true);
      await first.setHomeSetupState('f2', HomeSetupState.started);
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('ui_home_setup_f1'), 'hidden');
      expect(prefs.getString('ui_home_setup_f2'), 'started');

      final again = UiSettingsProvider();
      await _loaded(again);
      expect(again.homeSetupState('f1'), HomeSetupState.hidden);
      expect(again.homeSetupState('f2'), HomeSetupState.started);
      expect(again.homeSetupState('f3'), isNull);
    });

    test('Hide tells the listeners; a save while Home builds does not', () async {
      SharedPreferences.setMockInitialValues({});
      final ui = UiSettingsProvider();
      await _loaded(ui);
      var told = 0;
      ui.addListener(() => told++);
      await ui.setHomeSetupState('f1', HomeSetupState.started);
      expect(told, 0);
      await ui.setHomeSetupState('f1', HomeSetupState.hidden, notify: true);
      expect(told, 1);
    });
  });
}

