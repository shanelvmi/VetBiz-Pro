# POLISH AUDIT (POL1 Step A, read-only)

Taken at `9e56050` (2026-11-15). Nothing was fixed in this step. Every row is
a place that breaks one of the owner's five rules (POL1 brief): one accent,
colour only for success/warning/danger/neutral, one status style (dot plus
word), flat stat cards (surface, hairline, no gradient/glow/shadow), spacing
from the scale only.

**Sizes.** P = phone (`AppLayout.isPhone`), W = tablet and computer (they
share the wide layout on every screen below), All = every size. A list that
moved to the PH5a phone pattern already drops its summary cards on phones,
so its cards are W only.

**Groups** (the owner's order of how often they are seen; nine areas were
folded into the eight groups the brief asks for, by shared code):

| Group | Screens |
|---|---|
| 1 | Notifications (page, phone page, bell dropdown, `NotificationRow`), Subscription history |
| 2 | Home (dashboard, phone Home, Today card, Insights, action panel, banner, All details) |
| 3 | Sales and Services (lists, archives, add forms, receipt previews: the same helpers twice) |
| 4 | Products (Products, Stock Store, Stock alerts, Batches, add/edit product) |
| 5 | Clients and Debtors (with Payments and Transactions, the money lists) |
| 6 | Reports (view, review, detail, past, tabbed content, full view) |
| 7 | Settings and admin (Settings pages, Team, Facilities, picker, Activity, Subscription, sign-in/register, legal, help) |
| 8 | Platform Admin (operator console, stays English) |

Kinds: GR gradient, SH BoxShadow for decoration, EL elevation for decoration,
CC coloured category/type/method chip or badge, CI decorative icon in a
coloured circle or tile, SC summary/stat card, SP ad-hoc spacing, RD mixed
radii, ST status shown as a coloured pill (to become StatusDot).

## 1. Gradients (GR): 11

| File:line | Screen | Size | What it shows | Proposed fix | G |
|---|---|---|---|---|---|
| dashboard/today_card.dart:129 | Today card | P | brand gradient behind the day's amounts | flat `primary` fill, onPrimary text | 2 |
| dashboard/insights_screen.dart:367 | Insights, Business pulse | W | brand gradient card with glow (SH :373) | FlatStatCard | 2 |
| login_screen.dart:367 | Sign-in, brand panel | W | full-height brand gradient | flat `brandSurface` | 7 |
| login_screen.dart:662 | Sign-in card | W | gradient accent line along the top edge | remove (hairline border) | 7 |
| login_screen.dart:1081 | Sign-in button | W | base gradient, hover reverses | flat `primary` button | 7 |
| login_screen.dart:1101 | Sign-in button | W | hover overlay gradient | remove | 7 |
| register_screen.dart:971 | Register, brand panel | W | brand gradient | flat `brandSurface` | 7 |
| register_screen.dart:1020 | Register, step badge | W | gradient circle | flat `primary` | 7 |
| register_screen.dart:1080 | Register, step badge (done) | W | gradient circle | flat `primary` | 7 |
| subscription/subscription_screen.dart:368 | Subscription, current plan | All | gradient card with accent glow (SH :375) | FlatStatCard, plan name in primary | 7 |
| platform_admin/promotions_screen.dart:128 | Promotions card header | W | gradient strip | flat surface | 8 |

## 2. BoxShadow for decoration (SH): 39 calls in 25 files

| File:line | Screen | Size | What | Fix | G |
|---|---|---|---|---|---|
| dashboard/notifications_screen.dart:1622 | urgent announcement card (`_AccentCard`) | All | card shadow | hairline `border` | 1 |
| widgets/notification_row.dart:59 | bell dropdown and Stock alerts rows | All | card shadow | hairline `border` | 1 |
| dashboard/dashboard_screen.dart:1848 | wide dashboard tiles | W | card shadow | hairline | 2 |
| dashboard/home_action_panel.dart:210 | phone action panel | P | lift shadow over content (functional: separates a sheet) | keep, allowlist "sheet edge" | 2 |
| dashboard/insights_screen.dart:351, 373, 478 | Insights cards, pulse glow, chart cards | W | shadow, coloured glow | hairline; glow removed | 2 |
| dashboard/subscription_banner.dart:191 | floating phone banner | P | overlay shadow (functional: floats over content) | keep, allowlist | 2 |
| sales/sales_screen.dart:377 | Sales summary card | W | card shadow | FlatStatCard | 3 |
| sales/add_sale_screen.dart:331 | Add sale, floating total | All | shadow a30 | hairline | 3 |
| sales/receipt_preview_screen.dart:753 | receipt paper | All | paper shadow (receipt stays light) | keep, allowlist "paper" | 3 |
| services/services_screen.dart:331 | Services summary card | W | card shadow | FlatStatCard | 3 |
| services/service_receipt_preview_screen.dart:724 | receipt paper | All | paper shadow | keep, allowlist "paper" | 3 |
| products/products_screen.dart:209, 630, 1052 | metric card, grid card, product card | W | card shadow | hairline / FlatStatCard | 4 |
| products/stock_alerts_screen.dart:370 | alert card | W | card shadow | FlatStatCard | 4 |
| store/stockstore_screen.dart:151, 550, 951 | metric card, rows, product card | W | card shadow | hairline / FlatStatCard | 4 |
| clients/clients_screen.dart:217 | Clients metric card | W | card shadow | FlatStatCard | 5 |
| debtors/debtors_screen.dart:407 | Debtors metric card | W | card shadow | FlatStatCard | 5 |
| payments/payments_screen.dart:600, 647 | metric card, outstanding card | W | card shadow | FlatStatCard | 5 |
| transactions/transactions_screen.dart:321 | summary card | W | card shadow | FlatStatCard | 5 |
| facilities/facility_screen.dart:2440, 2734 | header card, metric card | W | card shadow | hairline / FlatStatCard | 7 |
| legal/legal_document_screen.dart:134 | legal page card | All | card shadow | hairline | 7 |
| login_screen.dart:559, 1147 | error box glow (dangerAccent), button glow | W | coloured glow | remove | 7 |
| register_screen.dart:880, 1505 | error box glow, card shadow | W | coloured glow, shadow | remove / hairline | 7 |
| subscription/subscription_screen.dart:375 | current plan accent glow | All | coloured glow | remove | 7 |
| widgets/auth_card.dart:66, auth_panel.dart:20, 25, 68, 69 | sign-in and register cards, icon circle glow | W | shadow and glow | hairline; glow removed | 7 |
| widgets/summary_card.dart:159 | `SummaryCard` (Home, Add client, Record visit) | W | shadow (`shadow:` parameter) | FlatStatCard | 2 |

## 3. Elevation for decoration (EL): 58 non-zero

39 are AppBar `elevation: AppElevation.e1` (a shadow under every app bar;
proposed: `e0` plus a hairline bottom `divider`, one change per group). The
other 19 are cards: `notifications_screen.dart:637` and
`subscription_history_screen.dart:360` (the category/summary cards, G1);
`dashboard_screen.dart:1278, 2180`, `all_details_screen.dart:124` (G2);
`sales_screen.dart:567`, `sales_archive_screen.dart:305`,
`services_screen.dart:373`, `services_archive_screen.dart:308` (G3);
`products_screen.dart:766`, `stock_alerts_screen.dart:834`,
`stockstore_screen.dart:673` (G4); `clients_screen.dart:846`,
`debtors_screen.dart:477`, `payments_screen.dart:993`,
`transactions_screen.dart:248` (G5); `manage_assistants_screen.dart:1507`,
`settings_screen.dart` (4 x `cardElevation`), `export_data_screen.dart` (3),
`manage_account_screen.dart` (4), `printer_settings_screen.dart` (3) (G7);
`widgets/hover_elevate_card.dart:53` (hover lift, G8). Functional, keep:
`notification_bell.dart:79` (dropdown e8), `add_sale_screen.dart:2113, 2191`
and `add_edit_service_screen.dart:1210` (bottom bars e6).

## 4. Coloured category/type/method chips and badges (CC): 14 helpers

| File:line | Helper | Screen | Size | Colours what | Fix | G |
|---|---|---|---|---|---|---|
| dashboard/notifications_screen.dart:416, 1039 | `_categoryColor`, `_categoryChip` | Notifications | All | category (6 hues, one raw `Color(0xFFE59A00)`) | grey label under the title | 1 |
| dashboard/notifications_screen.dart:1029 | `_typeIcon` (`type.colorIn`) | Notifications | All | type (chart4/6/8/9, info...) in a tinted circle | neutral icon, no circle tint | 1 |
| widgets/notification_row.dart:82 | type icon circle | bell dropdown, Stock alerts | All | type | neutral icon (bell logic untouched) | 1 |
| dashboard/notifications_screen.dart:1560 | `_sectionHeader` count pill | bell dropdown | All | warning-tinted count | SectionLabel | 1 |
| products/stock_alerts_screen.dart:1078 | `_categoryChip` | Stock alerts | All | product category in primary pill | grey text | 4 |
| products/products_screen.dart:217 | metric icon tile | Products | W | per-metric hue | neutral | 4 |
| services/services_archive_screen.dart:372 | `_categoryChip` | Services archive | All | filter chip, primary fill when selected | FilterRow | 3 |
| facilities/facility_screen.dart:2278 + widgets/facility_type_tag.dart:22 | `FacilityTypeTag` | Facilities, picker, profile menu | All | facility type (success/info/chart4) | grey text | 7 |
| admin/manage_assistants_screen.dart:587, 1366 | `_roleChip`, `_roleInk` | Team | All | role (owner/co-admin/assistant hues) | grey text | 7 |
| platform_admin/users_tab.dart:195 | `_roleColor` | Users | W | role | grey text | 8 |
| platform_admin/user_detail_screen.dart:367 | `_roleChip` | User detail | W | plan/role | grey text | 8 |
| platform_admin/facilities_directory_tab.dart:479 | `_chip` | Directory | W | totals in primary + status hues | FilterRow | 8 |
| platform_admin/promotions_screen.dart:274 | `_InfoChip` | Promotions | W | info tags | grey text | 8 |
| payments/payments_screen.dart:687 | `_trendPill` | Payments | W | trend (trendUp/trendDown, D7) | keep roles, one pill style | 5 |

## 5. Status shown as a coloured pill (ST): 9 helpers

`subscription_history_screen.dart:580` `_statusChip` and
`subscription_screen.dart:594` `submissionStatusColor` (G1; rejected is
`dangerAccent`), `notifications_screen.dart:1053` `_statusChip` New/Read (G1),
`sales_screen.dart:217`, `sales_archive_screen.dart:196`,
`services_screen.dart:192`, `services_archive_screen.dart:187`
`_statusColor(paid,total)` (G3, four copies of one mapping),
`stock_alerts_screen.dart:1059` `_alertChip` (G4),
`manage_assistants_screen.dart:758, 1773` (G7),
`facility_screen.dart:1417, 1424, 3035` `buildStatusChip`, `_miniBadge` (G7),
`subscription_screen.dart:263` (G7), `facilities_directory_tab.dart:105`,
`subscription_requests_tab.dart:81` `_urgencyColor` (G8). Fix: StatusDot.

## 6. Summary and stat cards (SC): 19 helpers

| File:line | Helper | Size | Repeats a filter? | Fix | G |
|---|---|---|---|---|---|
| notifications_screen.dart:599, 624 | 5 category cards | W (P: chips) | yes (category) | removed, FilterRow | 1 |
| subscription_history_screen.dart:285, 341 | 4 status cards | All | yes (status) | removed, FilterRow | 1 |
| widgets/summary_card.dart:64 | `SummaryCard` (dashboard x8) | W | no | FlatStatCard | 2 |
| dashboard_panels.dart:333 | `_glanceStat` | W | no | FlatStatCard | 2 |
| insights_screen.dart:338 | Business pulse | W | no | FlatStatCard | 2 |
| sales_screen.dart:355 / services_screen.dart:309 | status grids | W | yes (paid/partial/unpaid) | FilterRow | 3 |
| add_client_screen.dart:767 / add_edit_service_screen.dart:869 | form summaries (SummaryCard) | All | no | FlatStatCard | 3, 5 |
| products_screen.dart:158, 201 / stockstore_screen.dart:103, 143 | metric rows | W | partly (stock state) | FlatStatCard | 4 |
| stock_alerts_screen.dart:796, 821 | alert kind cards | W | yes (kind) | FilterRow | 4 |
| clients_screen.dart:211 / debtors_screen.dart:399 | metric cards | W | no | FlatStatCard | 5 |
| payments_screen.dart:593, 637 / transactions_screen.dart:315 | metric, outstanding, summary | W | no | FlatStatCard | 5 |
| past_reports_screen.dart:371 / report_tabbed_content.dart:439 | `_summaryStat`, `_summaryTile` | All | no | FlatStatCard | 6 |
| manage_assistants_screen.dart:1433, 1488 | status cards | W | yes (status) | FilterRow | 7 |
| facility_screen.dart:2719 | `_metricCard` | W | no | FlatStatCard | 7 |
| platform_admin/overview_tab.dart:250 | `_StatCard` | W | no | FlatStatCard | 8 |

## 7. Decorative icons in coloured circles or tiles (CI): 52 `BoxShape.circle`

Decorative (to neutralise): the card icon tiles in every SC helper above
(26 px tinted squares: notifications, subscription history, sales, services,
stock alerts, team, debtors), `notifications_screen.dart:1034`,
`notification_row.dart:82`, `products_screen.dart:217`,
`stock_alerts_screen.dart:380`, `stockstore_screen.dart:160`,
`manage_assistants_screen.dart:906`, `facility_screen.dart:2632`,
`legal_document_screen.dart:160, 216, 253`, `how_to_use_screen.dart:69`,
`register_screen.dart:1517, 1887`, `auth_panel.dart:64` (with glow),
`subscription_requests_tab.dart:302` (urgency-tinted avatar).
Not decorative (keep): status dots, chart legend swatches, avatars and
logos, skeleton circles, unread badges, the theme swatches in UI Settings.

## 8. Spacing and radii (SP, RD)

The scale has 15 steps (`AppSpacing.s2`..`s32`); a screen uses 6 to 14 of
them, so gaps inside a group differ by screen. Raw (non-token) gaps left:
`crossAxisSpacing: 12` / `mainAxisSpacing: 12` and `mainAxisExtent: 90`
(notifications :608, the same in 5 other card grids), `width: 26 / height: 26`
icon tiles (notifications, subscription history, 4 more). Radii: card files
mix `r7`/`r10`/`r12` on one card (`notifications_screen.dart:1151, 1157`
border r12 with clip r10; subscription history :708, :714 the same); pills use
`r10`, `r12` or `r20` by screen. Fix: PolishMetrics names one gap per level
(in group `s8`, between groups `s16`, between sections `s24`) and one card
radius (`r12`); screens adopt them group by group.

## 9. Generic generated look (HARD-LOOK)

Rainbow badges: notifications categories (6 hues), team roles (3), facility
types (3), platform roles. Glow: sign-in error box and button, register error
box, auth icon circle, subscription current plan, Insights pulse. Decorative
icons in coloured circles: every summary card and notification row.
Emoji-style empty states: none found (all empty states use a grey outline
icon); but subscription history's and notifications' empty icons are 64 px.
Mixed radii: see section 8.

## 10. Counts per kind

| Kind | Count |
|---|---|
| GR gradients | 11 (6 files) |
| SH decorative BoxShadow | 39 calls (25 files; 4 functional to allowlist) |
| EL elevation | 58 (39 app bars, 19 cards; 4 functional) |
| CC coloured category/type/method helpers | 14 |
| ST coloured status pills | 9 helpers (16 call sites) |
| SC summary/stat card helpers | 19 (6 only repeat a filter) |
| CI coloured circles (`BoxShape.circle`) | 52 (about 24 decorative) |
| SP/RD | 2 raw grid gaps x 6 grids, 6 raw 26 px tiles, 2 mixed-radius cards |
