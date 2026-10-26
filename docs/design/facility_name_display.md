# FN1: the facility name exactly as typed, never joined with the type

Batch FN1 (RUNBOOK2 ledger). **Owner decision, Option A:** the facility NAME is shown exactly as the customer typed it everywhere (dashboard header, receipts, PDFs, reports, dropdowns, invites) and is never joined with the facility type, because customers name their business freely ("Ukuli Animal Care", "Ukuli Vetagro Centre") and the app printed names such as "Ukuli Animal Care Agrovet". The type is only a classification, shown as a small tag in three places: the facility picker (as today), the Facilities cards and the business profile. No tag on the dashboard header. The type changes no behaviour: it only colours the picker chip and was joined onto names.

Audit at `fc93169`. Searched `lib/` for `facilityType`, `facility['type']`, `['type']`, `_nameWithType`, `'$facilityName $facilityType'`, `facilityDisplayType`, `facilityTypeDisplay`, `dashboard_facilityNameType`, `facilities_nameWithType`, `kVetPracticeTypes`, `typeDetail`, `facilityName`, and every receipt, PDF, printer and export file.

**No data migration:** the stored name and type do not change. Existing facilities simply show their name alone.

## 1. Every place that joins or shows the name and the type

| # | File:line | Today | Decision |
|---|---|---|---|
| 1 | `lib/main.dart:1201-1206` (no-facility screen, invite code) | "You'll be asking to join: {name} ({type})" (`noFacility_askingToJoinWithType`) | **name only** (`noFacility_askingToJoin`); key retired |
| 2 | `lib/main.dart:996-1015` (no-facility screen, Add facility) | label "Facility name", hint "e.g. Ukuli", type label "Type" | **wording** (section 2) |
| 3 | `lib/screens/dashboard/dashboard_screen.dart:2416-2427` (sidebar header) | "{name} {type}" (`dashboard_facilityNameType`); bare Other adds nothing | **name only**, no tag; key retired |
| 4 | `dashboard_screen.dart:1054` ("How {name} is doing") | name | **name only** through `FacilityDisplay.name` |
| 5 | `lib/screens/facilities/facility_screen.dart:1502-1508` `_nameWithType`, used at `:1556` (list row) and `:1705` (card header) | "{name} {type}" (`facilities_nameWithType`) | **name + tag** (the picker's chip, shared); key retired |
| 6 | `facility_screen.dart:2830-2831` (About: "Facility Type" row) | type on its own row | **leave** (a separate row, not joined) |
| 7 | `facility_screen.dart:471, 484` (Add facility) and `:749, 762` (Edit facility) | "Facility Name", no hint, type label "Type" | **wording** (section 2) |
| 8 | `facility_screen.dart:1128-1171` (delete: type the name to confirm) | the stored name | **leave** (typed confirmation compares the stored name exactly) |
| 9 | `lib/screens/admin/manage_assistants_screen.dart:128-139` `_nameWithType`, `:172` (`facilityNames`: table, cards, filter, search, the Team Members dropdown, reassign and invite pickers) | "{name} {type}" unless the name already contains the type | **name only** |
| 10 | `lib/services/role_change_service.dart:134-142` `_facilityLabel`, used `:230, 239, 246` (Platform Admin role change dialog and its notifications) | "{name} {type}" unless contained | **name only** |
| 11 | `lib/screens/reports/view_reports_screen.dart:200-203` (print) and `:211-214` (share) | "{name} {type}" into the daily report PDF | **name only** |
| 12 | `lib/screens/reports/report_detail_screen.dart:29-33` (print) | "{name} {type}" | **name only** |
| 13 | `lib/services/daily_report_pdf_service.dart:97` (page header), `:120` ("Facility" row) | whatever the caller passes | **name only** (fixed at 11, 12) |
| 14 | `lib/screens/sales/receipt_preview_screen.dart:189-192` (A4 print), `:227` and `:286-289` (A4 preview), `:588-591` (thermal preview header), `:798-801` (details panel "Facility") | "{name} {type}" unless the type is empty or 'Other' | **name only**; the tagline line `:592-596` unchanged; the `facilityType` parameters removed |
| 15 | `lib/screens/services/service_receipt_preview_screen.dart:179-182`, `:208`, `:263-266`, `:553-556`, `:769-772` | same | **name only**; tagline `:560-564` unchanged; parameters removed |
| 16 | `lib/services/receipt_pdf_service.dart:321-330` `_facilityHeaderBlock` (A4 header), `facilityType` parameters at `:44-249` | "{name} {type}" | **name only**, parameters removed; `_pageHeader` `:304` already name only |
| 17 | `lib/utils/receipt_texts.dart:21-31` `ReceiptTexts.facilityType` | the English type after the name | **removed** (no caller left); its pins in `test/rw2b2_titles_types_test.dart:68-75` go |
| 18 | `lib/services/receipt_printer_service.dart` (thermal printer, Bluetooth) | prints `AppInfo.name`, no facility name or type | **leave** |
| 19 | `lib/screens/settings/export_data_screen.dart` (CSV and Excel) | no facility name or type in the contents (`data['type']` is the record's own type) | **leave** |
| 20 | `lib/screens/register/assistant_steps.dart:57-58` (step 3, "Joining: {name} ({type})") | joined | **name only** |
| 21 | `lib/screens/register/review_step.dart:22` (assistant) and `:29` (owner, each facility) | "{name} ({type})" | **name only** (Change opens step 3, which shows the type) |
| 22 | `lib/screens/register/owner_steps.dart:84-95` (step 3 name) and `:124-145` (type) | "Facility name", hint "e.g. Ukuli", type label "Type" | **wording** (section 2) |
| 23 | `lib/screens/register_screen.dart:1858` (step 3 tile under the name: "{type} · Code: {code}") | the type on its own line | **leave** (not joined: a separate line about what is being created) |
| 24 | `lib/screens/register_screen.dart:1811` (Edit Profile, read-only facility) | "{name} ({type})" | **name only** |
| 25 | `lib/screens/facilities/facility_picker_screen.dart:449-461` (chip), `:149-153` (search and filter by type) | the chip | **tag**, unchanged look, now the shared widget; search and filter **leave** |
| 26 | `lib/screens/facilities/select_facility_screen.dart:311` (older picker route) | type on its own line | **leave** (a picker, not joined) |
| 27 | `lib/widgets/product_catalog_side_panel.dart:82, 131-136` (Products and Stock Store panel) | type on a line under the name | **name only** (the type line goes: not one of the three places) |
| 28 | `lib/screens/settings/business_profile_screen.dart:96, 114` | name | **name + read-only row** "Type of facility" |
| 29 | `lib/screens/debtors/debtors_screen.dart:1366-1371` (WhatsApp/SMS reminder) | name only | **leave** (customer message, text unchanged) |
| 30 | `subscription_screen.dart:175`, `manage_account_screen.dart:179`, `facility_activation.dart:199` | name only | **leave** |
| 31 | `lib/screens/platform_admin/*` (`facilities_directory_tab.dart:416`, `facility_detail_screen.dart:304`, `user_detail_screen.dart:95, 644`) | type as its own field | **leave** (operator console, never joined) |
| 32 | `lib/constants/client_options.dart:25` `kVetPracticeTypes` | a CLIENT's practice type | **leave** (not the facility type) |

ARB keys that become unused and are retired (both languages): `dashboard_facilityNameType`, `facilities_nameWithType`, `noFacility_askingToJoinWithType`, and `facilities_nameLabel` once the forms use `common_facilityName`. `register_joining` keeps its text; its description becomes "the facility's name".

## 2. Registration wording (owner wizard step 3, Add facility, Edit facility, the no-facility Add)

- Field label: **"Facility name"** (`common_facilityName`, already this text; the Facilities forms move off "Facility Name").
- Hint inside the box: **"e.g. Ukuli Animal Care"** (`common_facilityNameHint`, was "e.g. Ukuli"; Kiswahili draft "mf. Ukuli Animal Care").
- Helper line under the box: **"As it should appear on your receipts"** (new `facilities_nameHelper`, Kiswahili draft "Kama litakavyoonekana kwenye risiti zako"), wraps to two lines on narrow phones, no overflow at 360 px.
- Dropdown label: **"Type of facility"** (new `facilities_typeOfFacility`, Kiswahili draft "Aina ya kituo"), also the business profile row.

## 3. Tests (written first)

- `FacilityDisplay.name(rawName)`: trimmed, never adds a type.
- For "Ukuli Animal Care" with type Agrovet, and with type Other plus typeDetail "Pet shop": the sale and service receipt previews, the sale and service A4 PDFs, the daily report PDF (header and Facility row), the dashboard header and the Team Members dropdown entry all show exactly "Ukuli Animal Care", and no type word.
- Source test: `lib/` contains no name-and-type glue (`'$facilityName $facilityType'`, `'$name $type'`, a `+` of the two) and none of the retired keys.
