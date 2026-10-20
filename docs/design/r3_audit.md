# R3 audit: money, payment methods, app name (D1 to D6)

Read-only audit at fb9cf58. Line numbers are at that commit. Found by searching `lib/` for
`Tsh|TSh|TZS`, `currencySymbol|currencyCode`, every `Money.*(` call (261 calls in 41 files),
`NumberFormat|toStringAsFixed`, `PaymentMethod|Tigo|Mixx|paymentMethodLabel|iconForPaymentMethod`,
`VetBiz|AppInfo|appName`, and the ARB files. No code changed in this commit.

## Money API after R3 (`lib/config/money.dart`)

| Method | Output for 12500.5 | For -12500 | Use |
|---|---|---|---|
| `format` | Tsh 12,501 | -Tsh 12,500 | every total, balance, amount shown (D2, D3) |
| `plain` | 12,501 | -12,500 | the same, where the symbol is in a column header or label |
| `unitPrice` | Tsh 12,500.5 | -Tsh 12,500 | a unit price: up to 2 decimals when the stored value has them (D3) |
| `unitPricePlain` | 12,500.5 | -12,500 | the same without the symbol |
| `compact` | Tsh 12.5K | -Tsh 12.5K | the facility card (was its own `_formatCompact`) |
| `compactMillions` | Tsh 12,501 | -Tsh 12,500 | dashboard breakdown: "Tsh 10.888M" from a million (was inline) |
| `formatStored` | Tsh 12,501 | -Tsh 12,500 | a document value of unknown type (was `symbolAsStored`, "Tsh 50000.0") |
| `saved` | Tsh 12,501 | -Tsh 12,500 | NEW saved activity text (D4) |
| `decimal` | 12,500.5 | -12,500 | KEPT for text fields people edit only (rounding a prefill would change the saved value) |

Removed once unused: `symbolPlain` (D2), `symbolDecimal`, `symbolWhole`, `symbolAsStored` (D3), `savedWhole`, `savedAsStored` (D4).
Rounding: intl rounds half away from zero, so a total of 12,500.5 shows "Tsh 12,501"; the stored 12500.5 is unchanged.

## D1 currency spelling "Tsh"

| File:line | Today | After |
|---|---|---|
| sales/receipt_preview_screen.dart:624 | TOTAL `'TSh ${Money.plain(...)}'` "TSh 12,500" | `Money.format` "Tsh 12,500" |
| services/service_receipt_preview_screen.dart:590 | same | same |
| facilities/facility_screen.dart:1874 | facility card `'${AppDefaults.currencyCode} ${_formatCompact(x)}'` "TZS 1.2M" | `Money.compact` "Tsh 1.2M" |
| facilities/facility_screen.dart:2337, 2358 | `'${currencySymbol} ${_formatCompact(x)}'` (inline) | `Money.compact` (same text) |
| facilities/facility_screen.dart:1222-1226 | `_formatCompact` | removed (moved into Money) |
| l10n/app_en.arb:598 | `@common_totalValue` description "TSh 12,000" | "Tsh 12,000" (a translator note) |
| tool/hardcoded_baseline.json:202-213 | two R8 allowlist entries for 'TSh' | removed (baseline down) |

Already "Tsh" through `AppDefaults.currencySymbol`: every Money method, the receipt PDF and thermal printer
(via Money), the field labels (add_batch 210, add_edit_product 527/543, add_sale 200/1121/1145/1441/1443,
add_edit_service 770/790, add_transaction 373, platform_settings 549), dashboard series names 2127-2133,
Settings 226/374. Kept: `AppDefaults.currencyCode` 'TZS' in settings_provider.dart:18, 24 is the ISO code
stored in the currency setting, never shown before an amount.

## D2 one negative shape "-Tsh 12,500"

| Where | Today for -12500 | After |
|---|---|---|
| `symbolPlain` (33 calls: clients_screen 618; add_payment 131, 385, 445, 489; debtors 1372, 1379; payments 567, 614, 701, 905, 1009, 1081; facility_detail 330; overview_details 232, 307, 406; overview_tab 197; sales_screen 826; services_screen 783; insights 249, 256, 266, 521, 534, 540, 565, 638, 762, 774; subscription 397, 406, 415) | Tsh -12,500 | `format` -Tsh 12,500 |
| `symbolDecimal` (96 calls, see D3) | Tsh -12,500 | -Tsh 12,500 (sign first in D2, moved to `format` in D3) |
| dashboard_screen.dart:2427-2430 `_formatCompactAmount` | Tsh -10.888M | `Money.compactMillions` -Tsh 10.888M |
| receipt_pdf_service.dart:451 Discount row | "- Tsh 500" | `Money.format(-discount)` "-Tsh 500" |
| report_review 483, daily_report_pdf 516, report_full_view 377 variance | "+Tsh 500" / "Tsh -500" | "+Tsh 500" / "-Tsh 500" |
| `format` (48 calls) | -Tsh 12,500 | unchanged |

Customer reminder text (debtors 1372, WhatsApp/SMS, English) only changes for a negative balance, which it never sends.

## D3 decimals (display only; stored numbers never change)

`symbolDecimal` -> `format`: dashboard 1378, 1389, 1395, 1405, 1411, 1421, 1428, 1446, 1463, 1476, 1482, 1495, 2354, 2430;
past_reports 394; report_full_view 229-236, 252, 268, 327, 343, 370, 372, 377, 378, 417, 433; report_review 417, 451, 483;
report_tabbed_content 185-196, 324, 350, 402, 476, 490, 520, 526, 540, 719-721, 794, 854, 855, 972, 992, 994;
daily_report_pdf 214-222, 254, 261, 284, 346, 449-451, 487, 488, 510, 512, 516, 517; receipt_pdf 450-460;
transactions_screen 316, 465, 537, 584, 706; add_sale 1046, 1596; add_edit_service 744.
`symbolDecimal` -> `unitPrice` (unit prices): add_sale 426, 1578, 1786 (product sell price, item unit price).

`decimal` (display) -> `plain`: add_sale 1009, 1017, 1155, 1507; report_tabbed_content 469, 749-752, 788, 846;
daily_report_pdf 247, 280, 328, 342, 461-464, 483; receipt_pdf 194, 266 (x2), 271, 272.
`decimal` -> `unitPricePlain`: add_sale 1478; receipt_pdf 193. (receipt_pdf 271, a service item, -> `plain`, as its preview.)
`decimal` KEPT (a text field's prefill, parsed back on save): add_sale 187, 505, 831, 1243, 1276, 1715; add_batch 55;
platform_settings 477; report_review 55; thousands_input_formatter 38.

`symbolWhole` ("Tsh 12500", no separator) -> `format`: facility_detail 79; trash_screen 105, 117;
receipt_printer 147, 155, 165, 218, 226, 236, 285. -> `unitPrice`: view_batches 397, 492.
`symbolAsStored` ("Tsh 50000.0") -> `formatStored`: facility_detail 368; subscription_requests_tab 308, 534; subscription 588.
`format` on a unit price -> `unitPrice`: products 708, 1155, 1173; stockstore 651, 1083, 1099.
`plain` on a unit price -> `unitPricePlain`: receipt_preview 531; add_edit_service 684. Kept `plain`: add_edit_service 140-154 (prefills, whole already).
Inline -> Money: receipt_printer 134 (unit price `toStringAsFixed(0)` -> `unitPricePlain`), 136, 207 (-> `plain`, gains the separator).
Kept inline on purpose: debtors_screen 1274 (CSV export cell, a raw number), add_edit_product 309/313 (text field prefills),
percentages (clients 159, dashboard 2015, insights 765, payments 647, summary_card 337, promotions, subscription 360/362).

## D4 saved activity text "Tsh 12,500"

`savedWhole`/`savedAsStored` -> `Money.saved`: sale_provider 529 (recorded sale), 601 (deleted sale); service_provider 468 (recorded),
623 (updated), 678 (deleted, was "Tsh 12500.0" for a double); transaction_provider 312 (added), 384 (updated);
add_payment_screen 381 (recorded payment). Old entries are not touched. Nothing reads amounts back out of descriptions.

## D5 payment methods: one name "Mixx by Yas"

Stored keys ('Tigo Pesa', 'Mixx by Yas') never change; no record is rewritten. New helpers in `lib/config/payment_methods.dart`:
`PaymentMethod.shownKey` ('Tigo Pesa' -> 'Mixx by Yas', others unchanged), `storedKeysFor` (a filter on Mixx by Yas
matches both keys), `mergeShown`/`combineShown` (sum a by-method map under the shown key).

| Where | Today | After |
|---|---|---|
| l10n/stored_labels.dart:140 `paymentMethodLabel('Tigo Pesa')` (every list, detail and report row: payments 762, 1076; report_full_view 369, 383; report_review 411-513; report_tabbed 470, 490, 540, 972, 992; sales 949; sales_archive 665; services 685, 883; services_archive 559, 702; subscription_history 660, 681; transactions 532, 737) | "Tigo Pesa" | "Mixx by Yas" |
| widgets/payment_method_selector.dart:27 icon | generic payment icon | phone icon (`Icons.phone_android`, as Mixx by Yas) |
| providers/payment_provider.dart:146, 188, 246, 258 Payments filter query | `isEqualTo` the chosen key | `whereIn: storedKeysFor(key)` (Mixx by Yas finds old Tigo Pesa entries; same indexes) |
| subscription_history_screen.dart:222, 230 filter | two choices | one choice, compared by shownKey |
| services/daily_report_service.dart:339, 380 grouping | by stored key | by shownKey: a new report has one Mixx by Yas row and one reconciliation row |
| report_full_view 395-433, report_tabbed_content 481-540, 945-994, daily_report_pdf 255-261, 292-346 | maps read as stored | through `mergeShown`/`combineShown` (old reports with both keys show one row) |
| daily_report_pdf 248 (sales row), 509, 526 (reconciliation) | stored key | shownKey |
| Receipts: receipt_preview 611, 639; service_receipt_preview 578, 605; receipt_pdf 185, 262; receipt_printer 278 | stored key | shownKey |
| l10n ARB `paymentMethod_tigoPesa` | used by the label table | unused, removed (en, sw) |

Not changed: exported file contents (CSV/Excel keep the stored key, spec 2.8), `PaymentMethod.tigoPesa` itself (old records still parse).
Old report drafts generated before R3 with both keys keep two reconciliation rows (no customers yet, see E4-design).

## D6 app name "VetBiz Pro"

| File:line | Today | After |
|---|---|---|
| login_screen.dart:325, register_screen.dart:830 header `common_appSystem` | "VetBiz Pro System" | `AppInfo.name` "VetBiz Pro" (key removed from both ARBs) |
| login_screen.dart:407, 429 footer `login_copyright` | "© 2026 VetBiz Pro System. All rights reserved." | "© 2026 VetBiz Pro. All rights reserved." (sw draft "© 2026 {appName}. Haki zote zimehifadhiwa.") |
| settings_screen.dart:243 | `settings_versionLine(name, '1.0.0')` typed: "VetBiz Pro - v1.0.0" | `AppInfo.version` "VetBiz Pro - v2.0.0" |
| config/app_info.dart:15 | `versionLabel = 'v2.0.0'` (login footer) | `version = '2.0.0'`, `versionLabel = 'v$version'` |

Already `AppInfo.name`: main 116, dashboard 2674, 3081, facility_picker 221, login 484, platform_admin_home 353, register 896,
report_detail 29, view_reports 199/210, receipt previews 676/642, export_data 356, settings 629, daily_report_pdf 95/108,
receipt_pdf 303/315/482, receipt_printer 100/120/187/261.
Kept as written: legal text (privacy_policy, terms_of_service), the two-tone wordmark (receipt_texts 14, receipt_pdf 345,
receipt previews 568/655 and 542/630), code identifiers, package and bundle ids, Firebase ids, the asset name, server text
(functions/, not touched), `AppInfo.shortName`, `logoMark`, `logoInitials`. pubspec says 1.0.0+1; the login footer's v2.0.0 was the constant, so it wins.
