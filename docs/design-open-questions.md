# Design open questions (Phase 2)

Values and decisions the spec gives no home for. Each one is kept exactly as it is in the code until the owner decides.
Format: file, line, value, what it seems to be for.

## Open

Raised in step 2B. Each stays exactly as it is in the code until decided.

- Facility status, `lib/screens/facilities/facility_screen.dart:1229-1240, 2444, 2606`: `'Active'` / `'active'` / `'pending'` / `'inactive'`, compared case-insensitively. A third kind of "status" (not a user or payment-submission status). Its own enum in `lib/data`?
- Promotion `active` field, `lib/models/promotion.dart:78-152`, `lib/screens/platform_admin/promotions_screen.dart:228, 561`: `'active'` is a boolean field NAME on `promotions/{id}`, not a status value. Add it to `Fields`, or leave it with the model?
- Membership-history action keys, `lib/screens/admin/manage_assistants_screen.dart:242, 1650-1656`: `'approved'`, `'rejected'`, `'deactivated'`, `'reactivated'` are the `statusHistory[].action` values written by `functions/membership.js:92-95` (`history:`). Shared with the server, so an enum here would want a link test like UserStatus has.
- Activity type `'Sale'` vs `'Sales'`, `lib/screens/sales/add_sale_screen.dart:793` vs `lib/providers/sale_provider.dart:441, 570`: two spellings for sale entries, both already stored. The icon/colour readers lower-case and match `'sales'`, so entries written as `'Sale'` get the default icon. Both are kept in `ActivityType` (stored strings never change). Should new entries all write `'Sales'`? Old `'Sale'` entries would still need to display.
- Activity-type readers, `activity_log_screen.dart:348, 373`, `dashboard_screen.dart:1784, 1807`, `facility_screen.dart:1802, 1825`, `report_tabbed_content.dart:815, 840`: four copies of the same lower-case `switch` for icon and colour, including types nothing writes any more (`clients`, `settings`, `admin`). Keep as is, or one shared helper (a behaviour-neutral change, but outside 2B)?

### Money (raised in step 2C, for step 2R)

Every amount below keeps its exact current output through a named `Money` method, so each can be changed in one place later.

- **Saved text with no thousands separator** (`Money.savedWhole`, `Money.savedAsStored`): activity descriptions written to Firestore, e.g. "Recorded sale to Walk-in - Tsh 12500". `sale_provider.dart` (recorded, deleted sale), `service_provider.dart` (recorded, updated service; the deleted-service one prints the stored value as Dart does, so a stored double reads "Tsh 12500.0"), `transaction_provider.dart` (added, updated), `add_payment_screen.dart` (recorded payment). Old entries keep what they say; should NEW entries use "Tsh 12,500"? (A mixed log is the cost.)
- **On-screen and printed amounts with no thousands separator** (`Money.symbolWhole`): `facility_detail_screen.dart` plan price, `view_batches_screen.dart` (sell price, batch buy price), `trash_screen.dart` (item titles), `receipt_printer_service.dart` (thermal receipt: total, paid, balance, transaction amount). Not saved, so these could simply switch to `Money.symbolPlain`.
- **Raw stored values** (`Money.symbolAsStored`): subscription amounts shown as stored ("Tsh 50000", or "Tsh 50000.0" for a double): `facility_detail_screen.dart`, `subscription_requests_tab.dart` (2), `subscription_screen.dart`.
- **Three spellings of the currency**: "Tsh" (everywhere, `AppDefaults.currencySymbol`), "TSh" on the TOTAL line of the two receipt previews (`receipt_preview_screen.dart:609`, `service_receipt_preview_screen.dart:584`, left as typed: no home for it), and "TZS" before the facility card's compact total (`facility_screen.dart:1936`, now `AppDefaults.currencyCode`) where the same screen's other two totals say "Tsh". One spelling?
- **Two shapes for a negative amount**: `Money.format` gives "-Tsh 12,500", `Money.symbolPlain` gives "Tsh -12,500". Each screen keeps the one it had.
- **Decimals**: reports, PDFs, the dashboard and transactions use `Money.decimal` (up to 3 decimals, "12,500.5"); most other screens round to whole shillings. One rule?

### Payment methods: Tigo Pesa and Mixx by Yas (raised in step 2C)

Stored keys never change, and both display everywhere. Three places treat them as two different methods today; each is kept as it is:

- Icon (`lib/widgets/payment_method_selector.dart`, `iconForPaymentMethod`): Mixx by Yas gets the mobile-money phone icon; an old record stored as 'Tigo Pesa' gets the generic payment icon. Give Tigo Pesa the phone icon too?
- Daily report breakdowns (`daily_report_service.dart`, report screens, PDF): totals are grouped by the stored string, so a day with both shows two rows. Count them as one (display only; the stored keys stay)?
- Payments ledger filter (`payments_screen.dart:860`) and the subscription history filter: the ledger's method filter lists only current methods, so old 'Tigo Pesa' entries can only be seen under "All"; the history filter lists both as separate choices. Merge?

### Date formats (raised in step 2C)

- `lib/screens/services/add_edit_service_screen.dart:541`, `DateFormat.yMMMMd()` ("March 5, 2026"), now `AppDateFormat.monthDayYearLong`: the only date format that follows the locale; every other screen uses a fixed pattern such as `dd MMM yyyy` ("05 Mar 2026"). When step 2F turns on Kiswahili this one will change shape and the others won't. Switch it to `AppDateFormat.date` so it matches the rest?

### App name (raised in step 2C)

User-facing "VetBiz Pro" now reads `AppInfo.name` (titles, Settings, support line, register intro, report fallback names, export share text, PDF and thermal-receipt headers and footers). These keep the name typed, on purpose:

- **Must stay literal**: code identifiers (`VetBizProApp`, `VetBizLoadingIndicator`, `VetBizLoadingStyle`); the Dart package `vetbiz_pro` and bundle ids (`com.example.vetbiz_pro`, `com.example.vetbizPro`) across android/ios/linux/macos; the Firebase project id `vetbiz-pro` (`.firebaserc`, `firebase.json`); the asset `assets/vetbizpro_illustration.png`.
- **Legal text, left as written**: `lib/screens/legal/privacy_policy_screen.dart`, `terms_of_service_screen.dart`, and the "© 2026 VetBiz Pro System. All rights reserved." lines (`login_screen.dart:424, 446`).
- **The two-tone wordmark**: "VetBiz " and "Pro" as separately styled spans (`receipt_preview_screen.dart:568, 655`, `service_receipt_preview_screen.dart:542, 630`, `receipt_pdf_service.dart:342`). A logo, not a sentence: a new name would need a design decision.
- **Server text** (not touched in Phase 2): the credential email in `functions/index.js:37-51` says "VetBiz Admin" and "the VetBiz system".
- **Two names in use**: "VetBiz Pro" and "VetBiz Pro System" (login header, register header, © line). One name?
- **The version** "v1.0.0" is typed in Settings (`settings_screen.dart:239`); it could come from the build (pubspec) instead.

### Feedback copy (raised in step 2D-0)

- Sign-in error texts, now shared by the login screen and `FriendlyError` (`lib/ui/feedback/auth_error_messages.dart`), kept word for word. Against the copy rules (PHASE2_FEEDBACK_SPEC section 6) they end with a full stop and some say "Please":
  - "No account found with that email address."
  - "Incorrect password. Please try again." ("Please")
  - "Incorrect email or password."
  - "This account has been disabled. Contact your admin."
  - "Too many attempts. Please wait a moment and try again." ("Please")
  - "Network error - check your connection and try again."
  - fallback "Login failed. Please try again." ("Please"), and an unknown code shows Firebase's own message.
  Reword to the copy rules? (The login screen would change too.)

## Decided

Decided by the owner after step 2A.

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
