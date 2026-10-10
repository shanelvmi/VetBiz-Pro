# Design open questions (Phase 2)

Values and decisions the spec gives no home for. Each one is kept exactly as it is in the code until the owner decides.
Format: file, line, value, what it seems to be for.

## Open

For step 2R. Each needs before/after screenshots first; the owner's leanings are noted, not decided.

### Money (raised in step 2C, for step 2R)

Leanings: one currency spelling, "Tsh"; one decimals rule; one shape for a negative amount.

Every amount below keeps its exact current output through a named `Money` method, so each can be changed in one place later.

- **Saved text with no thousands separator** (`Money.savedWhole`, `Money.savedAsStored`): activity descriptions written to Firestore, e.g. "Recorded sale to Walk-in - Tsh 12500". `sale_provider.dart` (recorded, deleted sale), `service_provider.dart` (recorded, updated service; the deleted-service one prints the stored value as Dart does, so a stored double reads "Tsh 12500.0"), `transaction_provider.dart` (added, updated), `add_payment_screen.dart` (recorded payment). Old entries keep what they say; should NEW entries use "Tsh 12,500"? (A mixed log is the cost.)
- **On-screen and printed amounts with no thousands separator** (`Money.symbolWhole`): `facility_detail_screen.dart` plan price, `view_batches_screen.dart` (sell price, batch buy price), `trash_screen.dart` (item titles), `receipt_printer_service.dart` (thermal receipt: total, paid, balance, transaction amount). Not saved, so these could simply switch to `Money.symbolPlain`.
- **Raw stored values** (`Money.symbolAsStored`): subscription amounts shown as stored ("Tsh 50000", or "Tsh 50000.0" for a double): `facility_detail_screen.dart`, `subscription_requests_tab.dart` (2), `subscription_screen.dart`.
- **Three spellings of the currency**: "Tsh" (everywhere, `AppDefaults.currencySymbol`), "TSh" on the TOTAL line of the two receipt previews (`receipt_preview_screen.dart:609`, `service_receipt_preview_screen.dart:584`, left as typed: no home for it), and "TZS" before the facility card's compact total (`facility_screen.dart:1936`, now `AppDefaults.currencyCode`) where the same screen's other two totals say "Tsh". One spelling?
- **Two shapes for a negative amount**: `Money.format` gives "-Tsh 12,500", `Money.symbolPlain` gives "Tsh -12,500". Each screen keeps the one it had.
- **Decimals**: reports, PDFs, the dashboard and transactions use `Money.decimal` (up to 3 decimals, "12,500.5"); most other screens round to whole shillings. One rule?

### Payment methods: Tigo Pesa and Mixx by Yas (raised in step 2C, for step 2R)

Leaning: merge Tigo Pesa into Mixx by Yas for display, filters and report grouping (stored keys unchanged).

Stored keys never change, and both display everywhere. Three places treat them as two different methods today; each is kept as it is:

- Icon (`lib/widgets/payment_method_selector.dart`, `iconForPaymentMethod`): Mixx by Yas gets the mobile-money phone icon; an old record stored as 'Tigo Pesa' gets the generic payment icon. Give Tigo Pesa the phone icon too?
- Daily report breakdowns (`daily_report_service.dart`, report screens, PDF): totals are grouped by the stored string, so a day with both shows two rows. Count them as one (display only; the stored keys stay)?
- Payments ledger filter (`payments_screen.dart:860`) and the subscription history filter: the ledger's method filter lists only current methods, so old 'Tigo Pesa' entries can only be seen under "All"; the history filter lists both as separate choices. Merge?

### App name (raised in step 2C, for step 2R)

Leaning: one name, "VetBiz Pro".

User-facing "VetBiz Pro" now reads `AppInfo.name` (titles, Settings, support line, register intro, report fallback names, export share text, PDF and thermal-receipt headers and footers). These keep the name typed, on purpose:

- **Must stay literal**: code identifiers (`VetBizProApp`, `VetBizLoadingIndicator`, `VetBizLoadingStyle`); the Dart package `vetbiz_pro` and bundle ids (`com.example.vetbiz_pro`, `com.example.vetbizPro`) across android/ios/linux/macos; the Firebase project id `vetbiz-pro` (`.firebaserc`, `firebase.json`); the asset `assets/vetbizpro_illustration.png`.
- **Legal text, left as written**: `lib/screens/legal/privacy_policy_screen.dart`, `terms_of_service_screen.dart`, and the "© 2026 VetBiz Pro System. All rights reserved." lines (`login_screen.dart:424, 446`).
- **The two-tone wordmark**: "VetBiz " and "Pro" as separately styled spans (`receipt_preview_screen.dart:568, 655`, `service_receipt_preview_screen.dart:542, 630`, `receipt_pdf_service.dart:342`). A logo, not a sentence: a new name would need a design decision.
- **Server text** (not touched in Phase 2): the credential email in `functions/index.js:37-51` says "VetBiz Admin" and "the VetBiz system".
- **Two names in use**: "VetBiz Pro" and "VetBiz Pro System" (login header, register header, © line). One name?
- **The version** "v1.0.0" is typed in Settings (`settings_screen.dart:239`); it could come from the build (pubspec) instead.

## Decided

### D2 follow-up (decided after batch D2; done in D2f, the dialog swap in D2g)

- Modal barrier `Colors.black54` -> `scrim` at `AppAlpha.a50`.
- Offer banner gradient 0.75 -> `a70`.
- `AppIconSize.i24` added; the 26 px offer icon snaps to it. Icons 11 -> `i12`, 13 -> `i14`.
- Stock store shadow alpha 0.03 -> `a05`.
- "Release to Shop" -> "Release to Shelf" in both dialog texts of `release_to_shop_flow.dart` (identifiers and file names stay).
- `payments_screen.dart`'s private `_DateRangeDialog` is replaced by the shared `lib/widgets/date_range_dialog.dart`.
- The subscription history's inline load error shows `FriendlyError.messageFor(error)` instead of the raw error.

Other user-facing "shop", for a later copy pass (not changed): none left in `lib/` or `functions/` after the rename. The word remains only in code comments (`facility_screen.dart:1224` "how's this shop doing", `payments_screen.dart` "the whole shop's ledger") and identifiers (`release_to_shop_flow.dart`, `releaseProductToShop`, `_releaseToShop`).

The questions as raised:

- **Modal barrier** `Colors.black54`, `lib/screens/subscription/subscription_screen.dart` (`showSubscriptionScreen`): the spec maps black54 to `textSecondary`, but this is a scrim. `scrim` at 0.54 has no AppAlpha step. Snap to `scrim` + `a50`, or add `a55`?
- **Offer banner gradient**, `subscription_screen.dart`: `accent` fading to 0.75. No AppAlpha step and no snap rule. Snap to `a70`, or add `a75`?
- **Offer icon 26 px**, `subscription_screen.dart`: no `AppIconSize` step and no snap rule.
- **Icon sizes 11 and 13**, `lib/screens/payments/payments_screen.dart` (the trend-pill arrow, 11, like the summary card's, which was decided to snap to `i12`; the "Payment Received" check, 13). No step and no snap rule. Snap both to `i12`? `stockstore_screen.dart` has another 11 px icon (the list row's "Restock Shelf" badge; the card's badge uses 12).
- **Shadow alpha 0.03**, `lib/screens/store/stockstore_screen.dart` (metric cards): now the `shadow` role, but 0.03 is not in the snap table (0.04 and 0.06 snap to `a05`). Snap to `a05`?
- **"Shop" in the release flow**, `lib/screens/store/release_to_shop_flow.dart`: the dialog title "Release to Shop" and the question "Do you still want to release it to the shop?" call the selling shelf a shop (CLAUDE.md: never call a business a shop). The success message now says "to the shelf"; the two dialog texts are kept until a copy pass. "Release to Shelf"?
- **Duplicate date-range dialog**, `payments_screen.dart` `_DateRangeDialog`: a line-for-line private copy of `lib/widgets/date_range_dialog.dart` (same parameters, same output), now on the same tokens. Replace it with the shared widget (about 115 lines removed, no visible change)?

### D1 follow-up (decided after batch D1; done in D1c)

- `scrim` and `shadow` roles (exact `Colors.black`): `auth_background.dart` 0.18 -> `a20`, `notification_row.dart` 0.04 -> `a05`.
- `AppMotion.pulseSlow` (2 s, maintenance pulse), `emphasis` (900 ms one-shot: summary card glow, loading entrance), `float` (1400 ms: trend arrow; the 1500 ms loading subtitle pulse snaps to it).
- The 320 ms entry switcher (`facility_activation.dart`) snaps to `AppMotion.slow`.
- `AppTimeouts.tooltipDelay` (400 ms, trend tooltip).
- `AppIconSize.i48`; 44 (maintenance) snaps to it; the 11 px trend icon snaps to `i12`.
- `AppAlpha.a85` (selected-row count text); the animated 0.45 glow snaps to `a50`.
- Guard allowlist: `trial_period_helper.dart` `Duration(days: days)`, "computed from the configured trial days".
- The subscription-locked dialog keeps the 340 snap (`AppSizes.dialogXs`); the `dialogFixedWidth` comment now says 340.
- `trendUp` and `trendDown` stay separate roles; revisit in 2R.

The questions as raised:

- **Black scrim and shadow**, `lib/widgets/auth_background.dart:37` (`Colors.black` at 0.18 over the login photo) and `lib/widgets/notification_row.dart:47` (`Colors.black` at 0.04, a card shadow). The spec maps `Colors.black` to `textStrong`, but these are not text: in Dark Mode a text role turns light, a scrim or shadow should not. Add `scrim` and `shadow` roles (exact `Colors.black`)? 0.18 also has no AppAlpha step.
- **Maintenance pulse**, `lib/widgets/maintenance_gate.dart:162`: a 2 s repeating pulse. `AppMotion.loop` is 900 ms. Add `AppMotion.pulseSlow` (2 s)?
- **Entry switcher**, `lib/utils/facility_activation.dart:176`: `AnimatedSwitcher` 320 ms. Not in the motion table; nearest is `slow` (300). Snap?
- **Trial length**, `lib/utils/trial_period_helper.dart:30`: `Duration(days: days)` from the configured trial days. Business date math, not a literal; add a guard allowlist entry?
- **Icon sizes**: 48 (`firestore_error_view.dart:30`) and 44 (`maintenance_gate.dart:197`) have no `AppIconSize` step and no snap rule. Add `i48` (and snap 44 to it)?
- **Width snap applied**: the subscription-locked dialog (`lib/utils/subscription_guard.dart`) was 360 wide on wide screens; `AppSizes.dialogXs` makes it 340 (spec 4.10). The `AppBreakpoints.dialogFixedWidth` comment still says 360 and should change if the snap is kept.
- **One-shot 900 ms**, `lib/widgets/summary_card.dart:115` (the value-changed glow) and `lib/widgets/vetbiz_loading_indicator.dart:66` (the entrance): both play once, and `AppMotion.loop` (900) is for repeating motion. Add `AppMotion.emphasis` (900)?
- **Slow repeating floats**, `summary_card.dart:316` (trend arrow, 1400 ms, same value as `AppMotion.colorCycle` but a different purpose) and `vetbiz_loading_indicator.dart:92` (subtitle pulse, 1500 ms). Reuse `colorCycle`, or add a `float` token?
- **Tooltip delay**, `summary_card.dart:345`: 400 ms before the trend tooltip shows. A delay, not motion; leave inline or add to `AppTimeouts`?
- **Alphas with no step**: `summary_card.dart` glow `0.45 * glow` (animated) and `product_catalog_side_panel.dart` count text on a selected row (`onPrimary` at 0.85). Add `a85`, or snap to `onPrimaryMuted` (0.7)?
- **Trend icon 11 px** (`summary_card.dart`, compact pill): no `AppIconSize` step; the 12 px one became `i12`.
- **New colour roles** `trendUp` (`#10B981`) and `trendDown` (`#EF4444`): the trend pill's green and red, more than 12 away from `success` and `danger`. Merge into them in 2R?
- **Snaps applied here**: amber[700] -> `warning` ("Reorder Soon" dot) and grey[800] -> `textPrimary` (side-panel row labels), both per the 4.1 table; the loading screen's paw marks were the brand at alpha 0x0A (0.039), now `a05`.

### To do in the batch named

- **Services batch:** switch `DateFormat.yMMMMd` in `add_edit_service_screen.dart` to `AppDateFormat.date`, and list it as an output difference. As raised: `lib/screens/services/add_edit_service_screen.dart:541`, `DateFormat.yMMMMd()` ("March 5, 2026"), now `AppDateFormat.monthDayYearLong`: the only date format that follows the locale; every other screen uses a fixed pattern such as `dd MMM yyyy` ("05 Mar 2026"). When step 2F turns on Kiswahili this one will change shape and the others won't. Switch it to `AppDateFormat.date` so it matches the rest?
- **Login batch:** reword the sign-in texts to the copy rules, and merge "No account found with that email address." into "Incorrect email or password." so the screen does not reveal which emails are registered. Show the owner the before/after list. As raised:
  Sign-in error texts, now shared by the login screen and `FriendlyError` (`lib/ui/feedback/auth_error_messages.dart`), kept word for word. Against the copy rules (PHASE2_FEEDBACK_SPEC section 6) they end with a full stop and some say "Please":
  - "No account found with that email address."
  - "Incorrect password. Please try again." ("Please")
  - "Incorrect email or password."
  - "This account has been disabled. Contact your admin."
  - "Too many attempts. Please wait a moment and try again." ("Please")
  - "Network error - check your connection and try again."
  - fallback "Login failed. Please try again." ("Please"), and an unknown code shows Firebase's own message.
  Reword to the copy rules? (The login screen would change too.)

### For step 2E

- **New activity entries write `'Sales'`.** Both spellings stay readable, which also gives old `'Sale'` rows the right icon. As raised: Activity type `'Sale'` vs `'Sales'`, `lib/screens/sales/add_sale_screen.dart:793` vs `lib/providers/sale_provider.dart:441, 570`: two spellings for sale entries, both already stored. The icon/colour readers lower-case and match `'sales'`, so entries written as `'Sale'` get the default icon. Both are kept in `ActivityType` (stored strings never change). Should new entries all write `'Sales'`? Old `'Sale'` entries would still need to display.
- **One shared activity-type icon/colour helper** replacing the four copies. As raised: Activity-type readers, `activity_log_screen.dart:348, 373`, `dashboard_screen.dart:1784, 1807`, `facility_screen.dart:1802, 1825`, `report_tabbed_content.dart:815, 840`: four copies of the same lower-case `switch` for icon and colour, including types nothing writes any more (`clients`, `settings`, `admin`). Keep as is, or one shared helper (a behaviour-neutral change, but outside 2B)?
- **A `FacilityStatus` enum.** As raised: Facility status, `lib/screens/facilities/facility_screen.dart:1229-1240, 2444, 2606`: `'Active'` / `'active'` / `'pending'` / `'inactive'`, compared case-insensitively. A third kind of "status" (not a user or payment-submission status). Its own enum in `lib/data`?
- **`Fields.active`.** As raised: Promotion `active` field, `lib/models/promotion.dart:78-152`, `lib/screens/platform_admin/promotions_screen.dart:228, 561`: `'active'` is a boolean field NAME on `promotions/{id}`, not a status value. Add it to `Fields`, or leave it with the model?
- **A membership-history action enum, with a link test against `functions/membership.js`.** As raised: Membership-history action keys, `lib/screens/admin/manage_assistants_screen.dart:242, 1650-1656`: `'approved'`, `'rejected'`, `'deactivated'`, `'reactivated'` are the `statusHistory[].action` values written by `functions/membership.js:92-95` (`history:`). Shared with the server, so an enum here would want a link test like UserStatus has.

### Separate task, after 2D and before 2F

- **Make client deletion soft** (write to `trash_clients`) so it gets Undo. As raised: `ClientProvider.deleteClient` (`lib/providers/client_provider.dart`) deletes the client document outright, so its message ("Client deleted") has no Undo. Everything else that can be deleted from the app (products, sales, services, transactions) goes to a `trash_*` collection first. `trash_clients` is already supported end to end: `firestore.rules` has a rule for it, `functions/index.js` purges it after 30 days, and the Trash screen lists and restores it. Nothing in the app writes to it. Moving clients to Trash would give them Undo too (a behaviour change, so not done in Phase 2).

### Decided after step 2A


- `lib/theme/app_text.dart` (`AppText` colours): **caption → `textMuted`, bodySm → `textSecondary`, all others → `textPrimary`.** Applied in 2B-0.
- `lib/screens/subscription/subscription_screen.dart:395`, `'Tigo Pesa'`: **switch the subscription form to Mixx by Yas in step 2C, as its own commit.** New requests store `'Mixx by Yas'`; `PaymentMethod.tigoPesa` stays so old records still display.
- `lib/services/usage_calculator_service.dart:75`, `'Rarely'`: **keep all four restock frequencies.**
- `lib/data/subscription_keys.dart`, `'expired'`: **removed** (nothing stores it). Done in 2B-0.
- `lib/screens/admin/manage_assistants_screen.dart:452-468`, `'owner'`, `'coadmin'`: **a small `TeamMemberKind` enum (owner, coAdmin, assistant) next to the code that computes it, in that screen, not in `lib/data`.** Done in step 2B.
- Sidebar widths `240` (platform admin) and `250` (dashboard): **keep both.**
- `lib/screens/dashboard/dashboard_screen.dart:185`, `1400 ms`: **`AppMotion.colorCycle`.** Added in 2B-0.
- `sales_screen.dart:121` (2 s) and `services_screen.dart:110` (500 ms): **keep both, named separately:** `AppTimeouts.salesSummaryRefresh` and `AppTimeouts.servicesSummaryRefresh`. Added in 2B-0.
- File-name stamps `yyyyMMdd_HHmm` / `yyyyMMdd`: **in `DataKeys`.**
- `lib/services/receipt_pdf_service.dart:27`, `0xFFE0A32E`: **keep as `PdfPalette.amber`.**
