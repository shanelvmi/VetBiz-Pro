# Design open questions (Phase 2)

Values and decisions the spec gives no home for. Each one is kept exactly as it is in the code until the owner decides.
Format: file, line, value, what it seems to be for.

## Open

(none)

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
