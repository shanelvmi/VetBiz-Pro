# R1: the parked style values and the treatment D8 gives each

Batch R1 (RUNBOOK2 section 5), a DESIGN STOP: no code is changed. R2 applies this table exactly, once the last line says APPROVED.
Sources: every allowlist entry for R1 to R9 in `tool/hardcoded_baseline.json` (72 of its 81 entries; the other 9 are R10 and R11, text) and every Open item in `docs/design-open-questions.md` about a style value. Line numbers are at `f71b768`.

## How the D8 rule is read

- **Colour with no role:** used twice or more in `lib/` (outside `lib/theme`) -> **ROLE** (a new `AppColors` role named by purpose, exact value, so nothing changes on screen). Used once -> **SNAP** to the nearest role if every RGB channel is within 24; otherwise **KEEP**. "Distance" below = the largest per-channel difference.
- **Size or duration:** **SNAP** to the nearest token of the same kind (spacing, icon size, motion, timeout) within 4 px or 100 ms, otherwise **KEEP**. D8 does not say what to do with a tie, so ties go UP, as in the standing snap rule.
- **Not covered by D8:** alphas (no rule; all of them are more than 0.05 from a step, so **KEEP**), values the owner's D9 rule keeps as written (**KEEP, owner**), computed values and text (**not a parked value**).
- **Class (colours, for T0):** **BRAND-LINKED** = should follow the theme's primary, accent or background, so T0 must derive it per theme; **SEMANTIC** = success, warning, danger, info, the same in every theme; **ONE-OFF** = a fixed chart, category or illustration colour.
- **FLAG** marks a row where the mechanical result looks wrong. R2 applies the D8 result unless the owner changes the row.

## A. Colours (allowlist rule R1, 27 entries)

| # | File:line | Value | Used for | Uses | Nearest role (distance) | D8 treatment | Class |
|---|---|---|---|---|---|---|---|
| A1 | `main.dart:1119` | `Colors.orange.shade900` #E65100 | text of the "removed from facility" note | 1 | warningStrong (27) | KEEP | SEMANTIC (warning) |
| A2 | `activity/activity_log_screen.dart:692` | `Colors.blue.shade900` #0D47A1 | text of the assistant's scope note | 1 | roleOwnerStrong (35) | KEEP | SEMANTIC (info) |
| A3 | `admin/manage_assistants_screen.dart:697` | `Colors.teal` #009688 | Reassign button | 1 | roleCoAdmin, chart6 (0) | SNAP -> roleCoAdmin (same value, no visible change) FLAG: different purpose | BRAND-LINKED |
| A4 | `admin/manage_assistants_screen.dart:1299` | `Colors.teal.shade300` #4DB6AC | empty-team icon | 1 | infoNote (43) | KEEP | BRAND-LINKED |
| A5 | `dashboard/dashboard_screen.dart:155, 3168, 3369` | `Colors.teal.shade700` #00796B | drawer hover fill (items, platform-admin button, Logout) | 3 | roleCoAdminStrong (0) | ROLE `sidebarHover` = #00796B | BRAND-LINKED |
| A6 | `dashboard/dashboard_screen.dart:3169` | `Colors.teal.shade800` #00695C | platform-admin button press fill | 1 | roleCoAdminStrong (16) | SNAP -> roleCoAdminStrong FLAG: press then looks like hover; `sidebarHover` (A5) has the same value and fits the purpose better | BRAND-LINKED |
| A7 | `dashboard/dashboard_screen.dart:1629` | `deepAmber` #C77800 | subscription banner text and icon | 1 | chart3 (18) | SNAP -> chart3 (#B56A00) FLAG: a chart role on a warning banner | SEMANTIC (warning) |
| A8 | `dashboard/dashboard_screen.dart:1631` | `cream` #FFF6E7 | subscription banner fill (at alpha 0.92, see F7) | 1 | dangerSurface (9) | SNAP -> dangerSurface (#FFF1F0) FLAG: a danger tint on a warning banner | SEMANTIC (warning) |
| A9 | `dashboard/dashboard_screen.dart:189` | `Colors.redAccent` #FF5252 | the bell's `_BlinkingDot` default | 1 | dangerAccent (0) | KEEP, owner (D9 rule: the dot is left as written) | SEMANTIC (danger) |
| A10 | `dashboard/dashboard_screen.dart:2471` | #E3F0EC | Record Visit quick-action tint | 1 | divider (11) | SNAP -> divider (grey) FLAG: the owner reversed tint-to-grey snaps after D8 | BRAND-LINKED (primary tint) |
| A11 | `dashboard/dashboard_screen.dart:2487` | #FCEFD9 | Add Product quick-action tint | 1 | divider (21) | SNAP -> divider (grey) FLAG: as A10 | BRAND-LINKED (accent tint) |
| A12 | `dashboard/dashboard_screen.dart:351`, `dashboard/insights_screen.dart:39` | #5C7C99 steel blue | Services on the dashboard chart; service breakdown palette | 2 | infoNoteTextSoft, chart5 (14) | ROLE `chartServices` = #5C7C99 | ONE-OFF (chart) |
| A13 | `dashboard/insights_screen.dart:41` | #8FA998 sage | service breakdown palette | 1 | textHint (15) | SNAP -> textHint (grey) FLAG: see note 1 | ONE-OFF (chart) |
| A14 | `dashboard/insights_screen.dart:42` | #B98B6F terracotta | service breakdown palette | 1 | textHint (47) | KEEP | ONE-OFF (chart) |
| A15 | `dashboard/insights_screen.dart:43` | #9B8AA6 lavender | service breakdown palette, the "Other" slice | 1 | textHint (20) | SNAP -> textHint (grey) FLAG: see note 1 | ONE-OFF (chart) |
| A16 | `dashboard/insights_screen.dart:47`, `facilities/facility_screen.dart:53`, `login_screen.dart:59`, `register_screen.dart:513`, `platform_admin/platform_admin_home_screen.dart:67` | #3E8E82 login teal (`_tealAccent`, `tealAccent`, `tealGlow`) | login and register gradients, badges and links; Total Products metric; insights accent; operator sidebar badge | 5 | infoNoteText (32) | ROLE `brandTeal` = #3E8E82 | BRAND-LINKED |
| A17 | `login_screen.dart:60`, `register_screen.dart:514` | #7EE8CB `tealGlow` | light glow in the login and register gradients | 2 | textDisabled (63) | ROLE `brandTealGlow` = #7EE8CB | BRAND-LINKED |
| A18 | `dashboard/notifications_screen.dart:456` | #E59A00 | debt notification category colour | 1 | accent, warning (26) | KEEP | ONE-OFF (category) |
| A19 | `facilities/facility_picker_screen.dart:130` | `Colors.purple` #9C27B0 | facility type colour, "other" types | 1 | chart4 (0) | SNAP -> chart4 (same value, no visible change) | ONE-OFF (category) |
| A20 | `login_screen.dart:366` | `Colors.greenAccent` #69F0AE | "System Online" dot | 1 | textHint (82) | KEEP | SEMANTIC (success) |
| A21 | `platform_admin/subscription_requests_tab.dart:569` | `Colors.redAccent[700]` #D50000 | small bold label on a request card | 1 | dangerDeep (30) | KEEP | SEMANTIC (danger) |
| A22 | `platform_admin/users_tab.dart:486, 490, 541, 566, 572, 576` | `Colors.deepPurple` #673AB7 | Platform Admin chip, its icon, avatar fill | 6 | chart2 (36) | ROLE `rolePlatformAdmin` = #673AB7 | ONE-OFF (role category, like roleOwner) |
| A23 | `platform_admin/users_tab.dart:618` | `Colors.blue.shade100` #BBDEFB | pending status chip fill | 1 | border (37) | KEEP | SEMANTIC (info) |
| A24 | `platform_admin/users_tab.dart:618` | `Colors.orange.shade100` #FFE0B2 | other status chip fill | 1 | border (46) | KEEP | SEMANTIC (warning) |

A1 to A24 cover all 27 R1 entries: A12 is two entries (dashboard, insights), A16 five, A17 two; one entry each covers A3 and A4, A5 and A6, A23 and A24. Roles compared: every opaque `AppColors` role (`lib/theme/app_colors.dart:174`); the translucent ones (black87, white70...) are not snap targets.

**Note 1 (the service breakdown palette, A12 to A15):** D8 splits one four-colour palette three ways: steel blue gets a role, sage and lavender become the hint grey, terracotta stays. Two slices would then both be grey, next to each other. Alternative for the owner: four `chartService1..4` roles with the exact values (no visible change).

**Result for colours:** 5 new roles (`sidebarHover`, `chartServices`, `brandTeal`, `brandTealGlow`, `rolePlatformAdmin`) cover 18 uses; 9 snaps (A3 and A19 look the same afterwards; A6, A7, A8, A10, A11, A13 and A15 change on screen); 9 KEEP, plus A9 kept by the owner's rule. 8 FLAGs.

## B. Sizes (allowlist rule R4, 6 entries, and Open items)

| # | File:line | Value | Used for | Nearest token (distance) | D8 treatment |
|---|---|---|---|---|---|
| B1 | `services/daily_report_pdf_service.dart:214-224` | `pw.SizedBox(width: 230` | printed summary column width | none within 4 (sizes go up to `dialogXs` 340) | KEEP |
| B2 | `services/daily_report_pdf_service.dart:133` | `pw.SizedBox(width: 70` | printed header label column | i64 (6) | KEEP |
| B3 | `services/receipt_pdf_service.dart:370` | `pw.SizedBox(width: 100` | printed receipt label column | none within 4 | KEEP |
| B4 | `admin/manage_assistants_screen.dart:1292` | `vertical: 36` | empty-team gap | s32 (4) | SNAP -> `AppSpacing.s32` (4 px less) |
| B5 | `dashboard/dashboard_screen.dart:1981` | `vertical: 40` | gap around the chart spinner | s32 (8) | KEEP |
| B6 | `facilities/facility_screen.dart:2089, 2261` | `vertical: 40` (x2) | inventory and sales loading gaps | s32 (8) | KEEP |
| B7 | `platform_admin/announcements_tab.dart:37`, `products/view_batches_screen.dart:50` | `_fabClearance = 80` | list bottom gap clear of the floating button | none within 4 | KEEP |
| B8 | `dashboard/dashboard_screen.dart:357` | `_logoutClearance = 80` | gap under the profile panel | none within 4 | KEEP |
| B9 | `platform_admin/overview_details_screen.dart:37` | `_chartHeight = 220` | daily earnings chart height | none within 4 | KEEP |
| B10 | `register_screen.dart:523` | `_welcomePanelWidth = 290` | welcome panel beside the form | none within 4 | KEEP |
| B11 | `login_screen.dart:1169`, `register_screen.dart:718` | `targetWidth` 1100 / 480 (register 560) | page card width, wide and narrow | only breakpoints of the same value (`detailsSidePanel` 1100, `phoneNarrow` 480, `loginHeaderNarrow` 560) | KEEP: a breakpoint is not a width token FLAG |
| B12 | `dashboard/dashboard_screen.dart:3355` | `Icons.close, size: 28` | end-drawer close icon | i24 and i32 (4 each, a tie) | SNAP up -> `AppIconSize.i32` (4 px larger) |
| B13 | `facilities/facility_screen.dart:50-51` | `_listPanelHeight = 360`, `_listPanelWidth = 340` | list panel size | 340 equals `dialogXs` (a dialog width); 360 has none within 4 | KEEP both FLAG: 340 could use `dialogXs`, but that token is for dialogs |

## C. Named durations (allowlist rule R5)

| # | File:line | Value | Used for | Nearest token (distance) | D8 treatment |
|---|---|---|---|---|---|
| C1 | `dashboard/dashboard_screen.dart:100` | `_hoverFade` 200 ms | drawer hover fade | `AppMotion.normal` 220 (20) | SNAP -> normal |
| C2 | `dashboard/dashboard_screen.dart:101` | `_tooltipWait` 300 ms | drawer tooltip wait | `AppMotion.slow` 300 (0); `AppTimeouts.tooltipDelay` 400 (100) | SNAP -> `AppMotion.slow` (same value) FLAG: `tooltipDelay` fits the purpose but is 100 ms longer |
| C3 | `dashboard/dashboard_screen.dart:354` | `_bannerSwitch` 550 ms | subscription banner switch | slowest 500 (50) | SNAP -> slowest |
| C4 | `login_screen.dart:63` | `_announcementSlide` 600 ms | announcement carousel page | slowest 500 (100) | SNAP -> slowest |
| C5 | `login_screen.dart:67`, `register_screen.dart:518` | `_alertHoverGrace` 3 s | alert countdown restart after hover | `AppMotion.toastLong` 3 s (0) | SNAP -> toastLong (same value) |
| C6 | `login_screen.dart:68` | `_shakeDuration` 420 ms | form card shake | slower 400 (20) | SNAP -> slower |
| C7 | `login_screen.dart:69`, `register_screen.dart:517` | `_alertSwitch` 260 ms | alert fade-in | normal 220 and slow 300 (40 each, a tie) | SNAP up -> slow |
| C8 | `login_screen.dart:1300` | `_hoverSweep` 450 ms | Login button hover sweep | slower 400 and slowest 500 (50 each, a tie) | SNAP up -> slowest |
| C9 | `login_screen.dart:1460` | `_blinkStep` 600 ms | NEW badge blink step | slowest 500 (100) | SNAP -> slowest |
| C10 | `login_screen.dart:1461` | `_blinkHold` 3 s | NEW badge blink hold | toastLong 3 s (0) | SNAP -> toastLong (same value) |
| C11 | `register_screen.dart:521` | `_scrollToField` 350 ms | scroll to the first field in error | slow 300 and slower 400 (50 each, a tie) | SNAP up -> slower |

C2, C5 and C10 keep their values. The others change by 20 to 100 ms: C1, C3, C4, C6 to C9 and C11. A 3 s grace period taking a toast token is mechanical (C5, C10): the alternative is a new `AppTimeouts` entry with the same value.

## D. Kept by the owner's D9 rule (allowlist R5 and R7, no treatment)

| # | File:line | Value | Used for |
|---|---|---|---|
| D1 | `dashboard/dashboard_screen.dart:198, 207, 227` | 700 ms, 1400 ms, 400 ms | the bell's `_BlinkingDot` blink, colour cycle, colour fade (and its red default, A9) |
| D2 | `dashboard/dashboard_screen.dart:461` | 900 ms | delay before the subscription pill shows |
| D3 | `dashboard/dashboard_screen.dart:2821` | `width < 1024` (R7) | small-screen check beside the Layout Fixed Mode collapse (`AppBreakpoints.expanded` has the same value) |

## E. Not parked style values (allowlisted for another reason; R2 leaves them)

- **Computed durations (R5, 19 entries):** `trial_period_helper.dart` (trial days), `client_provider.dart` (2, overdue days), `activity_log_retention.dart` (retention days), `subscription_requests_tab.dart` (2, plan length and attended window), `overview_details_screen.dart` (chart day), `facility_detail_screen.dart` (override length), `login_screen.dart` (alert time from the message length, plus the false positive `_errorDisplayDuration(`), `register_screen.dart` (alert time), `dashboard_screen.dart` (5, week and chart date maths), `insights_screen.dart` (3, week and trend date maths). These are calculations, not style values.
- **Currency text (R8, 2 entries):** `'TSh ${Money.plain(` on the TOTAL line, `sales/receipt_preview_screen.dart:617` and `services/service_receipt_preview_screen.dart:583`. Decided by D1 ("Tsh"), applied in R3 (now LATER).

## F. Open items with no D8 rule (alphas and reviews)

| # | File:line | Value | Used for | Treatment |
|---|---|---|---|---|
| F1 | `products/add_edit_product_screen.dart:609, 666` | primary at alpha 0.95 | category and type picker dialog backgrounds | KEEP (0.10 above `a85`; D8 has no alpha rule) |
| F2 | `products/add_edit_product_screen.dart:267` | alpha 0.6 | photo placeholder icon | KEEP (0.10 from `a50`/`a70`) |
| F3 | `login_screen.dart:1186`, `register_screen.dart:726` | surface at alpha 0.97 | the card floating over the photo | KEEP (0.12 above `a85`) |
| F4 | `register_screen.dart:877` | onPrimary at alpha 0.6 | welcome panel "Log in" outline | KEEP (as F2) |
| F5 | `admin/manage_assistants_screen.dart:441` | alpha 0.6 | button outline (D4) | KEEP (as F2) |
| F6 | `lib/theme/app_colors.dart` | `chart8` amber 700, `chart9` deep orange | Reorder Soon and Debt Reminder categories (2E) | no change; ONE-OFF (category), reviewed with the chart roles in T0 |
| F7 | `dashboard/dashboard_screen.dart:1677` | cream at alpha 0.92 | subscription banner fill | KEEP (0.07 above `a85`) |
| F8 | PDF snaps from 2E | font 8, 8.5 -> 9; 9.5 -> 10; spacing 1.5 -> 2; 3.5, 5 -> 4 | daily report and receipt PDFs | already applied; the owner checks one printed report and receipt (no R2 change) |

## G. What R2 would change, and how to check it

- **Code:** 5 new `AppColors` roles (exact values, one value for every theme until T0 derives the brand-linked ones); 9 colour snaps; 2 size snaps (B4, B12); 11 duration snaps (C1 to C11, of which C2, C5 and C10 keep their value). Each removes its allowlist entry; the KEEP rows keep theirs, with a reason that points to this file.
- **Tests:** the guard (`flutter test`) with the allowlist shorter by the entries removed; `flutter analyze` at 0 issues. A test pins each new role's exact value.
- **Visible changes to check in Chrome (R2 is not a HARD STOP, so they get checked at T1):** the quick-action tints (A10, A11), the subscription banner (A7, A8), the drawer press (A6), the insights service slices (A13, A15), the empty-team gap (B4), the drawer close icon (B12), and the login, register and drawer timings.
- **Rollback:** each area is its own commit; reverting one restores its values and allowlist entries.

## For T0 (the theme work)

- **BRAND-LINKED (derive per theme):** A3, A4, A5, A6 (the sidebar hover and press), A10, A11 (quick-action tints of the primary and accent), A16, A17 (the login teal and its glow, also the operator badge and the Total Products metric).
- **SEMANTIC (same in every theme; contrast to check on each background):** A1, A2, A7, A8, A9, A20, A21, A23, A24.
- **ONE-OFF (fixed):** A12 to A15 (service palette), A18, A19 (categories), A22 (Platform Admin), F6.

OWNER DECISION: PENDING
