# LAYOUT AUDIT (LAY0, read-only)

Goal: one shared app shell for PC (>= 1024) and tablet (600-1023). The phone
(AppLayout.phone: < 600, or < 500 high while < 1024 wide) is untouched by
everything proposed here.

Audited at `062c6ce`. Facts come from reading the code (grep counts per file,
then the shell, the profile menu and the side panels by hand). The "wide
today" column is from the code's own breakpoints, not from a new measurement;
measured overflows are the numbers in docs/LAYOUT_DEFECTS.md (D1-D19 below).

Breakpoints that matter (lib/theme/app_breakpoints.dart): compact 600,
medium 900, expanded 1024 (sidebar), detailsSidePanel 1100, twoPane 820.

## Part 1: Screen inventory

Columns: **Tpl** template (L+D list+detail, form, dash, set settings-section,
wiz wizard, auth, adm admin, info, doc). **Own** = own Scaffold/AppBar
(every pushed screen has one). **Panel** = own side panel. **Lvl** nav level
(TOP top-level destination, SEC section, DET detail, MOD modal/form).
**Push** = Navigator.push / MaterialPageRoute calls in the file.
**Wide today**: 768 / 1024 / 1200.

| File (lib/screens/) | What it is | Tpl | Own | Panel | Lvl | Push | Wide today | Defects |
|---|---|---|---|---|---|---|---|---|
| dashboard/dashboard_screen.dart | Home + the shell (sidebar, top bar, profile drawer) | dash | yes | sidebar | TOP (root) | 20/20 | 768: AppBar + slide-in drawer sidebar; 1024/1200: permanent sidebar 250/72 + 72 px top bar; grid 3 cols, 4 above 1200 | - |
| dashboard/all_details_screen.dart | Home's "All details" page | dash | yes | no | DET | 0 | single column stretched | D18 (phone) |
| dashboard/insights_screen.dart | Insights | dash | yes | no | TOP (hub only, not in sidebar) | 0 | single column stretched | - |
| dashboard/notifications_screen.dart | Notifications | L+D | yes | no | SEC (bell, Settings) | 0/2 | own breakpoints (5) | - |
| dashboard/home_action_panel.dart | Phone hub action panel (widget) | - | no | no | phone only | 0 | n/a (phone) | - |
| sales/sales_screen.dart | Sales list + details panel | L+D | 2/4 | details | TOP | 5/5 | details panel 380 px; toolbar / page bar overflow at all three | D1-D4 |
| sales/sales_archive_screen.dart | Sales archive | L+D | yes | details | DET | 1/1 | page bar overflow 768/1024 | D8, D9, D12 |
| sales/add_sale_screen.dart | Record a sale | form | no AppBar | no | MOD | 0 | own breakpoints (3) | - |
| sales/receipt_preview_screen.dart | Sale receipt preview | doc | yes | preview side | DET | 1/1 | own breakpoints (3) | - |
| services/services_screen.dart | Services list + details | L+D | 2/4 | details | TOP | 4/4 | as Sales | D5-D7 |
| services/services_archive_screen.dart | Services archive | L+D | yes | details | DET | 1/1 | page bar overflow at every size | D10-D12 |
| services/add_edit_service_screen.dart | Record a visit / edit | form | no AppBar | no | MOD | 0 | own breakpoints (2) | - |
| services/service_receipt_preview_screen.dart | Service receipt preview | doc | yes | preview side | DET | 1/1 | own breakpoints (3) | - |
| products/products_screen.dart | Product catalog | L+D | yes | catalog panel (>= 900), Drawer below | TOP | 1/1 | 768: drawer; 1024/1200: panel + grid | none (POL5) |
| products/add_edit_product_screen.dart | Add / edit product | form | yes | no | MOD | 0 | two columns >= 860 | - |
| products/add_batch_screen.dart | Add batch | form | yes | no | MOD | 0 | stretched | - |
| products/view_batches_screen.dart | Batches of a product | L+D | yes | no | DET | 0 | stretched | - |
| products/stock_alerts_screen.dart | Stock alerts | L+D | yes | details | DET | 0/1 | own breakpoints (4) | fixed POL6 |
| store/stockstore_screen.dart | Stock Store | L+D | yes | catalog panel (>= 900), Drawer below | TOP | 1/1 | as Products | none (POL5) |
| clients/clients_screen.dart | Clients | L+D | 2/4 | details | TOP | 1/1 | page bar overflow with details | D13, D14 |
| clients/add_client_screen.dart | Add client | form | no AppBar | no | MOD | 1/0 | own breakpoints (2) | - |
| debtors/debtors_screen.dart | Debtors | L+D | 2/4 | details | TOP | 2/2 | toolbar, row actions, page bar overflow | D15 |
| debtors/add_payment_screen.dart | Record payment | form | no AppBar | no | MOD | 0 | stretched | - |
| payments/payments_screen.dart | Payments | L+D | 2/4 | details | TOP | 3/3 | toolbar overflow at all three | D16 |
| transactions/transactions_screen.dart | Transactions (income/expense) | L+D | 2/4 | details | TOP | 2/2 | time cell, toolbar, day header overflow | D17; pagination UI lost |
| transactions/add_transaction_screen.dart | Record transaction | form | no AppBar | no | MOD | 0 | own breakpoints (2) | - |
| reports/view_reports_screen.dart | Reports | dash | 2/2 | no | TOP | 3/3 | tabbed; card header overflow at 768 | D19 |
| reports/past_reports_screen.dart | Past reports | L+D | yes | no | DET | 1/1 | stretched | - |
| reports/report_detail_screen.dart | One saved report | doc | 2/2 | no | DET | 0 | stretched | - |
| reports/report_full_view_screen.dart | Report full view | doc | no AppBar | no | DET | 0 | stretched | - |
| reports/report_review_screen.dart | Review before saving | wiz | 2/2 | no | MOD | 0 | stretched | - |
| activity/activity_log_screen.dart | Activity log (admin) | L+D | 2/4 | no | SEC (profile menu) | 0 | stretched | - |
| admin/manage_assistants_screen.dart | Team Members | L+D | 3/5 | member details (>= 1100) | SEC (profile menu) | 1/1 | 768: cards (< 800 table); 1200: table + details panel | - |
| facilities/facility_screen.dart | View Facilities (admin) | L+D | 2/4 | details | SEC (profile menu) | 3/3 | own breakpoints (9) | - |
| facilities/facility_picker_screen.dart | Pick a facility after sign-in | auth | no AppBar | no | gate (main.dart) | 0 | centred card | - |
| settings/settings_screen.dart | Settings | set | 2/1 | section list 300 px (>= 900) + pane | TOP (sidebar) | 7/7 | 768: drill-down list (pushes); 1024/1200: master-detail | - |
| settings/business_hours_screen.dart | Business hours | set | yes | no | SEC | 0 | pane / stretched | - |
| settings/business_profile_screen.dart | Business profile | set | yes | no | **none: no caller (orphan)** | 0 | - | - |
| settings/export_data_screen.dart | Export data | set | yes | no | SEC | 0 | own breakpoints (2) | - |
| settings/manage_account_screen.dart | Manage account (erase etc.) | set | yes | no | SEC | 0 | pane | - |
| settings/printer_settings_screen.dart | Printer | set | yes | no | SEC | 0 | pane | - |
| settings/trash_screen.dart | Trash | set | yes | no | SEC | 0 | pane | - |
| subscription/subscription_screen.dart | Subscription & Billing | set | yes | no | SEC | 1/1 | pane | - |
| subscription/subscription_history_screen.dart | Subscription history | L+D | yes | details | DET | 0 | own breakpoints (4) | - |
| info/about_screen.dart, faq_screen.dart, how_to_use_screen.dart | Auth-footer info pages (wrap LegalDocumentScreen-style body, no Scaffold) | info | no | no | DET (from auth links) | 0 | via host | - |
| legal/legal_document_screen.dart | Legal document frame | doc | yes | "Key Points" sidebar (>= 820) | DET | 0 | 768: one column; 1024/1200: sidebar + text | - |
| legal/privacy_policy_screen.dart, terms_of_service_screen.dart | Content for the frame | doc | no | (frame's) | DET (auth links, register) | 0 | via frame | - |
| login_screen.dart | Sign in | auth | no AppBar | no | gate | 1/0 | auth panel two-up | - |
| register_screen.dart | Registration wizard | wiz | 2/0 | no | gate | 4/1 | two columns >= 720 | - |
| platform_admin/platform_admin_home_screen.dart | Operator console (English) | adm | 2/0 | own sidebar (Overview, Facilities, Users, Requests, Branding, Admins; Settings, Go to Facility, Logout) | TOP (own shell) | 2/1 | own collapsible sidebar | - |
| platform_admin/platform_settings_screen.dart | Console settings (tab body) | adm | no | no | SEC | 0 | in console | - |
| platform_admin/facility_detail_screen.dart | Facility detail | adm | yes | no | DET | 0 | stretched | - |
| platform_admin/user_detail_screen.dart | User detail | adm | yes | no | DET | 0 | own breakpoints (3) | - |
| platform_admin/overview_details_screen.dart | Overview drill-down | adm | yes | no | DET | 1/1 | own breakpoints (2) | - |
| platform_admin/promotions_screen.dart | Promotions | adm | yes | no | DET | 1/1 | own breakpoints (4) | - |

Totals: 58 `*_screen.dart` files; 84 `Navigator.push` and 80
`MaterialPageRoute` across lib/; no go_router in pubspec.

## Part 2: Shell facts

**Where the sidebar lives.** `dashboard_screen.dart` `_buildDrawerContent()`
(~:2506-2840), a top-level function inside the state. It owns: the facility
logo (Image.network, cached 180 px), facility name + tagline (its own
Firestore stream), 9 items (Stock, Products, Sales, Services, Clients,
Payments, Debtors, Transactions, Reports), Settings, Platform Admin (a
FutureBuilder on `_isPlatformAdmin()`), the `@AppName` footer, the collapse
state `_isDrawerCollapsed` (250 / 72 px, held open by Layout Fixed Mode),
and `_refreshDashboardData()` after most pushes. The same widget is the
permanent column at >= 1024 and the slide-in `Drawer` at 600-1023. The wide
top bar (`_buildTopBar`, :2090) owns the collapse button, product/client
search (Autocomplete), alerts bell, Help and the profile button. Profile end
drawer: `_buildEndDrawerContent` (:2912).

**Screens that hide the sidebar.** All of them. Every destination (sidebar,
top bar, profile drawer, Home cards, search) is a full-screen
`MaterialPageRoute` pushed over the Dashboard, so the sidebar exists only on
Home. Not a choice per screen: the sidebar is part of DashboardScreen, not of
a shell around routes. Back returns to Home, which refreshes its data.

**Own side panels.**

| Panel | Where | Shows at | Sections |
|---|---|---|---|
| Settings section list | settings_screen.dart (~:255) | >= 900 (medium) | Subscription & Billing; Account & Data (Trash, Export data, Business hours, Manage account); General (Notifications, Printer, App info); Preferences (Theme & layout = UI Settings dialog, Currency, Language) |
| Product catalog | widgets/product_catalog_side_panel.dart, used by products_screen and stockstore_screen | >= 900; a 324 px Drawer below | facility name, Categories, Stock status (All, In stock, Low, Reorder soon, Depleted, Expired) with counts |
| Team member details | manage_assistants_screen.dart :1169/:1930 | >= 1100 | the chosen member's details and actions |
| Legal "Key Points" | legal_document_screen.dart `_buildSidebar` :189 | >= 820 | the document's section anchors |
| Platform Admin sidebar | platform_admin_home_screen.dart `_buildSidebar` :543 | always, collapsible | Main Menu: Overview, Facilities, Users, Requests, Branding, Admins; Others: Settings, Go to Facility, Logout |
| Record details panel | widgets/record_list.dart + each L+D screen | details panel 380 px when a row is open | the record's details (table vs cards switch at medium) |

**One destination registry.** `hub_destinations.dart` (`HubTile`,
`hubGroupsFor`, `hubTileAllowed`, label/icon/keywords, search) already drives
the phone hub and the action panel. It can drive the sidebar and a tablet
rail once these are added:

- Missing destinations: Home, Settings, Notifications, Team, Facilities,
  Activity log (the last three are profile-menu items today).
- Missing fields: sidebar order (sidebar starts with Stock; hub with Sales),
  filled vs outlined icon (sidebar uses `.filled`), the screen builder
  (today `runHubTile` / a switch), a "refresh Home on return" flag, a stable
  route path for web URLs, and a "rail-visible" flag for the tablet subset.
- Mismatch to decide: Insights is in the hub but not the sidebar; Payments
  and Stock Store have no collapsed-hub tile (fine).

## Part 3: Profile panel (end drawer, wide only)

Built by `ProfileDrawerContent` (widgets/profile/profile_drawer.dart :78)
from `_buildEndDrawerContent` (dashboard_screen.dart :2912); the action rows
are `profileActionsFor` (dashboard/profile_actions.dart :35), the same list
as the phone's ProfilePage. Handlers: `_profileHandlers` (dashboard :2940).

| # | Item | Built by | Does | Recommendation |
|---|---|---|---|---|
| 1 | Close (X) | ProfileDrawerContent IconButton | closes the drawer | stay |
| 2 | Avatar | ProfileAvatar | display only | stay |
| 3 | Name | Text | display | stay |
| 4 | Role (Co-admin aware) | Text | display | stay |
| 5 | Email | _DetailRow | display | stay |
| 6 | Phone | _DetailRow | display | stay |
| 7 | Current facility + type tag | _DetailRow + FacilityTypeTag | display (no tap on wide; phone has Switch) | stay (personal context); add the facility switch to the top bar on wide (see Q5) |
| 8 | Edit Profile | ProfileDrawerRow (editProfile) | showEditProfileScreen modal | stay |
| 9 | Team Members (admin) | ProfileDrawerRow (team) | push ManageAssistantsScreen | move to sidebar (business place) |
| 10 | View Facilities (admin) | ProfileDrawerRow (facilities) | push FacilityScreen | move to Settings > Business |
| 11 | Change password | ProfileDrawerRow (changePassword) | dialog | stay (personal security) |
| 12 | Activity Log (admin) | ProfileDrawerRow (activityLog) | push ActivityLogScreen | move to sidebar (business record, admins) |
| 13 | Settings | ProfileDrawerRow (settings) | push SettingsScreen | remove as duplicate on wide (sidebar has it); keep on phone |
| 14 | Help | ProfileDrawerRow (help) | support contact dialog | remove as duplicate on wide (top bar has Help); keep on phone |
| 15 | Sign out | ProfileDrawerRow (signOut), destructive | confirm, then forceLogoutAndShowLogin | stay |
| - | Language | not in the menu today | (Settings > Preferences) | add a shortcut to the profile menu per the proposed rule, or leave in Settings only (Q3) |

Proposed rule: the profile menu holds only personal items (identity, Edit
Profile, Change password, language, Sign out). Business items go to Settings
sections or the sidebar.

**Phone impact.** `profileActionsFor` is one list for both. To change wide
only, give it a `wide` flag (or a layout argument) that drops items 9, 10,
12, 13, 14 on wide; the phone list stays byte-identical. Nothing changes for
the phone.

**Proposed Settings sections (wide).**

| Section | Filled by |
|---|---|
| Business | business_profile_screen (orphan today: wire it), business_hours_screen, facility_screen (View Facilities) |
| Team | manage_assistants_screen (if the owner prefers Settings over the sidebar, Q1) |
| Printer | printer_settings_screen |
| Notifications | notifications_screen (settings view) |
| Language & display | language dialog, currency, UI Settings dialog (Theme & layout) |
| Subscription | subscription_screen (+ subscription_history_screen as its detail) |
| Data | export_data_screen, trash_screen |
| Account | manage_account_screen |
| Legal & about | legal_document_screen (privacy, terms), App info |

## Part 4: Plan

**Migration order** (about 12-14 blocks, each <= 300 lines per the commit rule):

1. LAY1 Registry: extend hub_destinations (fields above), tests only on
   the data; no UI change. (1 block)
2. LAY2 Shell widget: extract `_buildDrawerContent` + `_buildTopBar` +
   end drawer out of dashboard_screen into an `AppShell` (sidebar >= 1024,
   rail 600-1023), fed by the registry; Dashboard renders inside it;
   pixel-identical fingerprints at 1024/1200. (2 blocks)
3. LAY3 Profile menu split (Part 3) with the `wide` flag. (1 block)
4. LAY4 Shell keeps the sidebar for top-level destinations: a nested
   Navigator in the shell's content area; sidebar pushes become "select
   destination". Low-risk screens first: Settings, Reports, Insights,
   Activity log. (2 blocks)
5. LAY5 Catalog screens: Products, Stock Store (own panel becomes the
   content's left column inside the shell). (1 block)
6. LAY6 Money list+detail screens: Clients, Debtors, Payments, Transactions,
   then Sales, Services and archives, fixing D1-D17 on the way. (4 blocks)
7. LAY7 Team, Facilities, Settings sections (Part 3 table). (1-2 blocks)
8. LAY8 Forms/modals: decide dialog vs pushed page inside the shell. (1 block)
   Platform Admin keeps its own shell (operator console), out of scope.

**LAY1 done** (registry, data only; no pixel moved). Not an extension of
hub_destinations, as item 1 first said: a separate `AppDestination` enum in
`lib/navigation/app_destinations.dart`, because the phone hub keeps its own
`HubTile` (record actions, Platform Admin) and must not change. Each place
holds its label (the sidebar's key today; Home `shell_tabHome`, Insights
`insights_title`), outlined and filled icon, section (Settings bottom),
`adminOnly` (false for all: today's sidebar gates nothing but Platform
Admin), `refreshHomeOnReturn` (where the sidebar calls
`_refreshDashboardData`) and an unused `webPath`. `shellDestinationsFor`
gives Home, Insights, today's nine in today's order, Settings;
`destinationForHubTile` links the phone tiles. Not members: Platform Admin
(outside the shell), Team, Facilities, Activity log, Notifications
(Settings sections, LAY7). Tests: `test/lay1_destinations_test.dart`.
LAY2 builds the sidebar and the tablet rail (same list, icons only) from it
and adds each place's screen. **Open for LAY2 (owner):** keep today's order
(Stock first) or lead with Sales, as on the phone and in the mockups. Also:
the sidebar says "Stock" (`nav_stock`) where the phone hub says "Stock
Store" (`store_title`); the registry keeps the sidebar's word. Today's sidebar draws every item with
the FILLED icon at rest; to stay pixel-identical LAY2 draws `selectedIcon`
until the owner chooses outlined-at-rest.

**Risks.**

- go_router ShellRoute vs 84 `Navigator.push` / 80 `MaterialPageRoute`:
  a full go_router move touches every caller and every test that finds
  screens by pushing. Recommendation: a nested Navigator inside the shell
  first (keeps every push working, just inside the content area); go_router
  only later if web URLs are wanted.
- Deep links / web URLs: today the URL never changes (single route), browser
  Back leaves the app's history only through Navigator; refresh always lands
  on Home. A nested Navigator keeps that; URLs need go_router (Q4).
- `await Navigator.push(...); _refreshDashboardData()`: Home refreshes on
  return. With a persistent shell, Home is not re-entered: needs a provider
  refresh or a "selected destination changed" hook.
- Root-level pushes that must still cover the shell: receipt previews,
  PdfPreview, the profile page, dialogs; `Navigator.of(context, rootNavigator:
  true)` choices must be made per call.
- Tests: 71 test files mention MaterialPageRoute or find screens by type;
  fingerprint tests (ph5a/ph5b/ph7b/pol4) pin today's wide trees and will all
  move when the shell wraps a screen. Each block re-baselines only the
  screens it moves.
- Phone: PhoneOrWide already splits in DashboardScreen; the shell must be
  built only in the `wide` branch so phone tests stay unchanged.

**Owner questions (yes/no).**

1. Team Members goes in the sidebar (not under Settings)?
2. Activity log goes in the sidebar for admins?
3. Add a Language shortcut to the profile menu (it stays in Settings too)?
4. Do you want real web URLs per screen now (go_router), rather than a nested
   Navigator first?
5. Add a facility switcher to the wide top bar?
6. On tablet (600-1023), a collapsed icon rail instead of today's slide-in
   drawer?
7. Insights in the sidebar too?
8. Forms (Add sale, Add client...) open as dialogs over the shell on PC,
   rather than full pages?
9. Wire the orphaned Business profile screen into Settings > Business?
10. Platform Admin console keeps its own sidebar and stays outside the shell?
