# Design open questions (Phase 2)

Values and decisions the spec gives no home for. Each one is kept exactly as it is in the code; the owner decides later.
Format: file, line, value, what it seems to be for.

## Step 2A

- `lib/theme/app_text.dart` (`AppText`): the spec gives the role styles' sizes and weights but not their colours. All eight use `textPrimary` (black87, the most-used text colour). Should `caption` be `textMuted`?
- `lib/screens/subscription/subscription_screen.dart:395`, `'Tigo Pesa'`: the subscription payment form lists Tigo Pesa, while the rest of the app (`kPaymentMethods`) lists Mixx by Yas, Tigo Pesa's new name. Both are kept in `PaymentMethod` because saved subscription requests may use either. Should the form switch to Mixx by Yas? (The stored key would still never change for old records.)
- `lib/services/usage_calculator_service.dart:75`, `'Rarely'` (7 / 14 / 30 days): the spec lists three restock frequencies; the code has four. All four are kept in `RestockRules`.
- `lib/data/subscription_keys.dart`, `'expired'`: listed by the spec, but not found as a stored subscription value in the app. Kept as a constant; is it written anywhere (server, platform admin)?
- `lib/screens/admin/manage_assistants_screen.dart:452-468`, `'owner'`, `'coadmin'`: display kinds worked out on screen, not stored roles. They stay out of `UserRole`. Should they get their own small enum in step 2B?
- `lib/screens/platform_admin/platform_admin_home_screen.dart:545`, sidebar `240` expanded vs the dashboard's `250` (`dashboard_screen.dart:3163`): kept as two tokens (`AppSizes.platformAdminSidebarExpanded`, `AppSizes.sidebarExpanded`). Align in 2R?
- `lib/screens/dashboard/dashboard_screen.dart:185`, `Duration(milliseconds: 1400)`: a repeating colour cycle, slower than `AppMotion.loop` (900 ms). It needs its own motion token or a 2R decision.
- `lib/screens/sales/sales_screen.dart:121` (2 s) vs `lib/screens/services/services_screen.dart:110` (500 ms): the same "refresh the summary after a change" delay, with different values. Both kept; classified in 2C.
- `lib/screens/settings/export_data_screen.dart:290`, `lib/screens/debtors/debtors_screen.dart:1276`, `yyyyMMdd_HHmm` / `yyyyMMdd`: file-name stamps, put in `DataKeys` (data, never localised).
- `lib/services/receipt_pdf_service.dart:27`, `0xFFE0A32E`: the receipt PDF's amber is not the brand accent (`0xFFFFB200`). Kept exact as `PdfPalette.amber`.
