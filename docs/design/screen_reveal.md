# RV1: ScreenReveal, one way for a screen to arrive

Batch RV1 (RUNBOOK2 ledger). Owner decisions are in the RV1 prompt: a shared architecture, Home first, the rest in RV2. Line numbers are at `0172729`.

## 1. Vocabulary

- **Reveal group**: the part of a screen that arrives as one piece (the phone Home list; the wide dashboard's card grid and lower panels). One group per screen instance, owned by one `RevealGate`.
- **Primary source**: data the group cannot be shown without (the Today card's figures, the grid's cards). Primary sources gate the reveal.
- **Secondary source**: data that fills one block inside the group (Needs attention, the chart, Recent Activity). It NEVER delays the reveal.
- **Late slot** (`LateSlot`): the box where a secondary block appears. Its size is reserved from the start: a soft skeleton until its data answers, then the content fades in inside the same box. Nothing around it moves.
- **Chrome**: what is not part of any group and is never hidden by a reveal: the app bar, the bell and its number, the subscription banner, the bottom bar, the sidebar, the greeting row.

## 2. Rules

1. A source counts as **answered** on its first data, an empty result or an error. A spinner, a `loading` flag turning true or a timer never answers it.
2. The gate opens when **all primary sources have answered**, or **1200 ms after the first frame** (`AppTimeouts.revealGate`), whichever comes first. States: `pending`, `revealed`, `timedOut`. It never closes again.
3. If every primary source has already answered when the screen is first built (cached data, a repeat visit, a rebuild after a resize), the content is shown **at once, with no skeleton and no rise**: the page transition already animates it.
4. Otherwise the skeleton is drawn at once, and when the gate opens the content arrives as **one** cross-fade plus a 12 px rise of the whole group, over the login entrance's duration and curve. It plays once per screen instance, never on rebuilds, resizes, theme or language changes.
5. When the gate opened on the timeout, primary blocks still waiting keep their own in-place placeholder (the grid cards' value spinner, the Today card's dashes); late slots fill on their own. No block changes size when its data arrives.
6. Under reduced motion (`MediaQuery.disableAnimationsOf`), nothing animates: the skeleton is swapped for the content instantly, a late slot swaps instantly, the skeleton does not pulse.
7. The skeleton is **excluded from the accessibility tree**; the content is built offstage while the gate is closed (so its own streams start at today's moment, not 1.2 s later) and is announced normally once shown.
8. A source adapter adds **no Firestore listener and no read**: it watches something the screen already has (the same stream passed through, a future it already awaits, a notifier, a provider it already reads).
9. Forms and screens with no asynchronous data are never wrapped: they open immediately.

## 3. Motion constants (`lib/theme/app_motion.dart`, `lib/config/app_timeouts.dart`)

| Name | Value | Use |
|---|---|---|
| `AppMotion.revealDuration` | 350 ms (= the login entrance, `authEntrance` now points to it) | the group's fade and rise; a late slot's fade |
| `AppMotion.revealCurve` | `Curves.easeOutCubic` (the login entrance's curve) | both |
| `AppMotion.revealRise` | 12 px (`authEntranceRise` points to it) | the group's rise |
| `AppMotion.pageSlide` | 280 ms, `easeOutCubic` | every pushed page |
| `AppMotion.pageSlideOffset` | 0.06 of the width (incoming, from the right) | |
| `AppMotion.pageSlideOutgoingOffset` | 0.03 of the width (outgoing, to the left) | |
| `AppMotion.tabFade` | 180 ms | the phone bottom-bar tab cross-fade |
| `AppTimeouts.revealGate` | 1200 ms | the longest first wait |

The skeleton's fill is `context.colors.surfaceMuted` with the phone list's soft pulse (`AppMotion.loop`, down to `PhoneListMetrics.skeletonLow`), so every skeleton in the app looks the same.

## 4. Adopting it in a screen (a few lines)

```dart
late final _gate = RevealGate(primary: [
  ListenableRevealSource(_totalsAnswered),                      // a notifier the screen sets on first data or error
  SelectorRevealSource(context.read<DebtProvider>(), (p) => p.loaded),
]);
// dispose(): _gate.dispose();
ScreenReveal(
  gate: _gate,
  skeleton: MyScreenBody(skeleton: true),        // the same widgets, drawn as SkeletonOf boxes
  child: MyScreenBody(...),
)
// a secondary block inside the body:
LateSlot(height: 220, ready: chartLoaded, child: chart)
```

`StreamRevealSource(stream)` exposes `.stream` (the same events, passed through: listen to that instead of the original, so no second subscription); `FutureRevealSource(future)` attaches to a future the screen already has. `SkeletonOf(child)` lays the real widget out invisibly and paints the soft box over it, so the skeleton has the content's exact size by construction (never with a widget that starts a stream: those get a plain `SkeletonBox` of their reserved size).

## 5. Navigation motion

- **Pages**: one `AppPageTransitionsBuilder` (`lib/theme/app_page_transitions.dart`) for every platform in `ThemeData.pageTransitionsTheme`. The incoming page slides in 6 % of the width from the right with a fade; the page under it moves 3 % to the left; the reverse on pop. On iOS and macOS it keeps the Cupertino back-swipe gesture (the builder delegates the gesture detection only). Dialogs and sheets are not page routes and do not change. The `pushReplacementNamed('/login')` routes (register and the wizard, `register_screen.dart:676`, `wizard_flow.dart:107`) keep today's platform transition: the builder hands any route named `/login` to Flutter's previous default builder, so the login keeps its own entrance. Sign-out does not push (AppEntryPoint swaps its content, PH3), and facility activation's `PageRouteBuilder` (`facility_activation.dart:152`) has its own transition and is untouched. Instant under reduced motion.
- **Tabs** (phone shell): the lazy `IndexedStack` stays (each tab keeps its state, a tab is built on its first visit). On a change the new tab fades in over the old one, which fades out, in `AppMotion.tabFade`. Only the selected tab is hit-testable and visible to accessibility; the bottom bar never animates. Instant under reduced motion.

## 6. Home audit

Phone Home (`dashboard_screen.dart:1561-1600`, `phone_home.dart`) and the wide dashboard (`dashboard_screen.dart:1240-1540`). "Listener" means a Firestore listener; RV1 adds none.

| Source | Used by | How it loads today | Class | Reason |
|---|---|---|---|---|
| Period totals (`watchDashboardTotals`, 4 listeners) | Today card Sales, Collected, Net profit; grid Sales, Collected, Net Profit, Expenses, Completed Services | live, subscribed after the first frame (`_loadPeriodTotals`) | **primary** (phone, wide) | the headline figures; dashes or spinners in their place are what the reveal replaces |
| Debts (`DebtProvider.debts`, app-level listener since activation) | Today card Owed; grid Outstanding; glance debtors; Needs attention | live; RV1 adds `DebtProvider.loaded` (first snapshot or error), no new listener | **primary** (phone, wide) | Owed and Outstanding read 0 before it answers, which looks like a real figure |
| Products (`ProductProvider.products`, `loaded`) | grid Total Product Value; Needs attention | phone: live since activation (PH4b); wide: one get at activation | **primary** on wide (a grid card); **secondary** on the phone | the phone shows no product figure; only the strip needs it |
| Clients (`ClientProvider.clients`, `hasLoaded`) | grid Total Clients | live since activation | **primary** on wide | a grid card |
| Previous period totals (one get) | the grid cards' trend pills | `_loadPreviousPeriodTotals`, wide only | secondary | the pill already has its own loading state in place (KpiTrend.isLoading) |
| Previous snapshot (one get) | trend pills of the "as of now" cards | wide only | secondary | same |
| Today at a Glance (four gets) | the glance strip | wide only | secondary, already a reserved box | the strip keeps its place with hidden values since DASH-1 |
| Chart data (seven gets) | Sales and Revenue chart | wide; phone only in All details | secondary, **LateSlot** (220 high box) | heavy, not needed to read the day |
| Recent Activity (1 or 2 listeners) | the feed | wide; phone only in All details | secondary, **LateSlot** inside the feed's reserved box (DASH-1) | can be slow; never worth delaying Home |
| Needs attention (memory: products, debts, `debtOverdueDays`) | phone strip | memory | secondary, **LateSlot** at the end of the list | last block of the list: while it waits it reserves one row; when it answers empty it is not drawn, and nothing is below it to move |
| User document (name, photo) | top bar, greeting row | stream, cached | chrome | one line of text either way, no size change |
| Bell (4 listeners), urgent, promotion, pending payments | top bar, banner | streams | chrome | not part of the reveal |
| Subscription banner | floats over the content | SubscriptionProvider | chrome | floats; never moves the content (PH8a-fix) |
| Quick access, Go to, quick actions | phone tiles and row, wide quick actions | static | none | no data: drawn in the skeleton as `SkeletonOf` boxes of their exact size |

Counts that must not change (PH4 / PH4b, measured on the counting fake): phone cold open 4 dashboard-owned listeners (the period totals) and 0 reads on a return to Home; wide cold open the five loads plus Recent Activity, as `dashboardLoadsFor` says. The test `rv1_home_counts_test.dart` pins them.

## 7. Tests (written first, committed skipped)

`rv1_reveal_gate_test` (fake clock), `rv1_screen_reveal_test` (once, rebuild, resize, theme, language, reduced motion, semantics, same rects when a slot fills), `rv1_page_transitions_test` (progress 0, 0.5, 1; a pushed route; dialogs and sheets untouched; reduced motion), `rv1_tab_fade_test` (state kept, only the selected tab hit-testable, lazy first visit), `rv1_home_test` (phones 360x740, 390x844, 740x360; wide 768x1024, 1024x768, 1200x800; Light, Dark, Kiswahili; skeleton = content layout), `rv1_home_counts_test`, and the login entrance's existing tests unchanged.
