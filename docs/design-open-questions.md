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
