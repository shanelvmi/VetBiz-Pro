# PH1 design (A): the phone shell and the phone home

Batch PH1 (RUNBOOK2 ledger), a DESIGN STOP: no code changed. Companion: `docs/design/phone_foundations.md` (B). Line numbers are at `2b9ceb8`. The first customers test on one phone, one tablet and one computer, through the web link.

## The owner's approved direction

Inspired by the structure (not the look, colours or icons) of a trading app. PHONES get a new shell; tablets and computers keep today's sidebar and card grid unchanged.

- **D1 Bottom bar** with five places: Home, Sales, a central round "+", Stock, More. "+" opens a bottom sheet with Record sale, Record service, Take payment, Add client, from ANY tab. The bar shows on the five top-level places; deeper screens (Add Sale, a receipt, Edit Product and the like) open FULL SCREEN over it with their own back arrow. Each tab keeps its place when the person switches. The bar hides while the keyboard is open. Roles decide what is shown.
- **D2 Phone home**: the top bar (avatar for the profile drawer, a two-line greeting over the name and title, the bell, Help); ONE "Today" card (Sales large; Collected, Owed and, for admins only, Net profit; a date chip; "All details"); "Quick access" (four big tiles, "View all" for add product, add batch, add expense); a scrolling "Go to" row of round shortcuts; a "Needs attention" strip drawn ONLY when something needs attention.
- **D3** No hamburger on phones (the bar and More replace it; the avatar still opens the profile drawer).
- **D4** The eight-card grid stays on tablets and computers; on phones it is one tap away under "All details", as a full-width LIST of rows (label left, value right), so titles never truncate.
- **D5** More is a page of round icons for everything else the role allows.

## 1. Navigation today

**The stack.** `facility_activation.dart:123` pushes the dashboard with `pushAndRemoveUntil(..., route.isFirst)`, so the stack is `[AppEntryPoint, DashboardScreen]`. `force_logout.dart:68` and `:95` rely on that (`popUntil(isFirst)`). Exception: `manage_account_screen.dart:168` uses `pushNamedAndRemoveUntil('/login', (route) => false)`, which removes AppEntryPoint too.

**How places open.** No router and no URL strategy: `main.dart:140` has three named routes (`/login`, `/register`, `/dashboard`); everything else is an unnamed `MaterialPageRoute` (80 `Navigator.push` in `lib/screens`). The dashboard opens:

| From | Places (file:line) | How |
|---|---|---|
| Sidebar (1024+) or drawer | Stock `:2249`, Products `:2261`, Sales `:2273`, Services `:2285`, Clients `:2296`, Payments `:2306`, Debtors `:2318`, Transactions `:2330`, Reports `:2341`, Settings `:2354`, Platform Admin `:2374` | `await push(...)`, then `_refreshDashboardData()` (not after Clients, Reports, Settings) |
| Profile drawer (`:2563`) | Edit Profile, Team Members `:2600`, Facilities `:2605`, Change password (dialog), Activity log `:2622`, Log out | push or dialog |
| Quick actions (`:1948`) | Record Sale, Record Visit, Add Product (admin) | `navigateOrShowLockedDialog` then `showAddSaleScreen` / `showAddEditServiceScreen` / `showAddEditProductScreen` |
| Glance strip (`dashboard_panels.dart:317`) | Insights | `showInsightsScreen` |
| Bell (`:2127`) | Notifications | 400 px dropdown at 900+, a page below |
| Settings (`settings_screen.dart:96-188`) | Subscription, Trash, Export, Business Hours (admin), Manage Account, Printer | push below the two-pane width, a pane above (`:399`) |

**What each place needs.** No arguments: every list screen reads `FacilityProvider.selectedFacilityId` and the app-level providers (`main.dart:79-100`). The form helpers take optional arguments; 15 copy one rule (a page below 900, a 60% modal above: `add_sale_screen.dart:1805`, `add_payment_screen.dart:588`). **Take payment** exists only inside Debtors (`debtors_screen.dart:436`, `:1055`, `:1162`); the stand-alone form needs `debtorClients` and `debtorBalances`, which Debtors fetches first (`_fetchAllDebtorClients`), so the "+" sheet needs that fetch moved to a shared function.

**Roles.** `UserRoleProvider.isAdmin`; a Co-admin is an admin in the app (the only difference is inside Team Members, `manage_assistants_screen.dart:542`). The sidebar shows all nine modules to an assistant; the gates are inside: Add Product (`:1985`), the masked Net profit and its trend (`:1328-1355`), the profile drawer's Team Members, Facilities and Activity log (`:2596`, `:2616`), Settings' Subscription, Trash, Export, Business Hours (`settings_screen.dart:81-136`, `:402-412`), and row actions in Sales, Services, Clients, Transactions, Stock Store and Products. Insights has no gate.

**Back and dead ends.** Only `register_screen.dart:929` uses `PopScope`. On the web, Navigator 1 with no Router means the browser back button pops the top route. Back on the dashboard pops it and uncovers AppEntryPoint, still signed in and showing its memoized decision screen (`main.dart:572`): a dead end to confirm on the owner's phone. Forms lose typed data on back without asking. A reload always restarts at AppEntryPoint, then the dashboard.

**What is lost on pop.** Each module is a new route each time: its search, filters, scroll position, page and open details panel are lost on back. The data survives in the providers (and the cursor lists in their controllers).

### Proposed shell architecture

| Option | How | Risks |
|---|---|---|
| **(a) Lazy IndexedStack, one root Navigator (recommended)** | A `PhoneShell` Scaffold with the bar; the four tab roots in an IndexedStack, each built on its first visit and then kept. Deep screens keep using `Navigator.of(context).push`, which is the root navigator, so they cover the bar with no change to the 80 pushes | Tab roots that are today full pages (`SalesScreen`, `ProductsScreen`) show an automatic back arrow (the root can pop), which would pop the whole shell: they need an `asTab` flag that hides it. A plain IndexedStack builds all tabs at once (all their listeners start): it must be lazy |
| (b) A Navigator per tab | Deep screens stay inside the tab, above the bar | Contradicts D1 (full screen over the bar) unless every push says `rootNavigator: true`; dialogs, `AppFeedback`, `force_logout`'s `popUntil` and the back button all need per-tab handling |
| (c) A router package with a stateful shell route | URLs per place; reload keeps the place | A new dependency (`pubspec.yaml`, not in this batch) and a rewrite of 80 pushes; later, if the owner wants links |

**Who owns what (option a).** `DashboardScreen` stays the one route and keeps every listener it owns today (session timer, bell feed, period totals). In `build` it chooses the shell or today's layout (`:1102`) from one signal (section 3). The shell's Scaffold owns the bar, the profile end drawer and the "+" sheet. The four places are Home (new), Sales (`SalesScreen(asTab: true)`), Stock (section 4) and More (new). A deep screen hides the bar simply by being a pushed route.

**The "+" sheet.** `showModalBottomSheet` on the root navigator (so it covers the bar), four rows. Each goes through `navigateOrShowLockedDialog` (`subscription_guard.dart:33`), as Record Sale does today, so a locked facility stays read-only for all four (today only Record Sale and Record Visit are guarded). The rows open the existing helpers, which on a phone are full pages.

**Back and reload.** A `PopScope` in the shell: back on a tab that is not Home goes to Home; back on Home does nothing (recommended, it removes the dead end) or asks "Leave?". A deep screen's back pops it as today. A reload opens Home (the tab is not restored; a deep screen never was).

**RecordChanges and providers.** Unchanged: the providers are app-wide and the tab roots are the same screens. One change: today the dashboard refreshes its gets after a pushed module returns (`:2253` and the rest). In the shell there is no return, so Home must read only live data (section 2) and refresh nothing on tab switch.

**Crossing the boundary** (a desktop window narrowed, a split screen) swaps the two layouts: the tab state is lost, the dashboard's listeners are kept. Accepted.

## 2. The data behind the home

| Piece | Source | Kind | Reads |
|---|---|---|---|
| Total Product Value | `ProductProvider.totalProductValue` | one get at activation (`facility_activation.dart:70`); live only after Products or Stock opens | 0 more |
| Total Sales, Collected, Net Profit, Expenses, Completed Services | `watchDashboardTotals` (`dashboard_summary_service.dart:154`): 4 listeners on daily summary collections | live | 1 doc each for Today; up to 7, 31 or 366 per stream for the longer periods |
| Outstanding, Total Clients | `DebtProvider.debts`, `ClientProvider.clients` | live, app-level, unbounded | 0 more |
| The 8 trends | previous period: `getDashboardTotals` (4 queries); `dailySnapshots/{date}` (1 doc) | gets | at least 5 |
| Today at a Glance | `_loadTodayGlance` (`:816`): 3 queries plus `getDashboardTotals` (4) | gets | at least 7 |
| Chart | `_loadChartData` (`:861`): 7 queries | gets | 7 to 49 (7 days), up to 210 (30 days) |
| Recent Activity | admin 1 listener, assistant 2 (`dashboard_panels.dart:37-45`), 5 entries | live | up to 5 or 10 |
| Bell | `NotificationFeedController` 4 listeners (`notification_feed.dart:298`), promotion 1 (`promotion.dart:120`), urgent announcements 1 (`:465`), pending assistants 1 (admin, `:486`) | live | |
| Greeting, avatar | `userDoc.snapshots()` built twice (`:1185`, `:2521`) | live, recreated on each rebuild | |

Every period change and every return from a module reruns all five loads (`:1080`, `:805`): at least 23 queries, about 65 reads with the 7-day chart. A period change also reloads the chart, which does not depend on the period.

**Listeners on the phone dashboard today:** 8 app-level (facility, subscription, user role, sales 25, services 25, transactions 25, all clients, all debts) plus 14 owned by the dashboard (admin: user doc 2, bell 4, promotion 1, urgent 1, pending 1, period 4, activity 1; an assistant has no pending and 2 for activity) = **22**.

**The Today card reuses**, with no new query: Sales, Collected, Net profit from the period listeners; Owed from `DebtProvider.totalOutstanding()`. Not reused: the glance's sale count (not on the card). Note that "Sales" is sales only (services are separate, as on the card today) and "Owed" is everything owed now, not credit given today.

**Needs attention**, all from memory, 0 new reads: low stock, depleted and expiring from `StockAlertsScreen.currentAlerts(products)` (`stock_alerts_screen.dart:107`, 30-day expiry window); overdue debts from `DebtProvider.debts` with the facility's `debtOverdueDays` (`facility_provider.dart:171`, default 30). Debts have no due date; "overdue" means older than that setting, as on Debtors. Missing: products are a one-time get until Products or Stock opens, so the strip would not see a sale's stock change. Fix: start `listenToProducts` at activation (1 listener; reads = product count once, then changes).

**After, on the phone home:** 8 app-level + user doc 1 (one cached stream) + bell 4 + promotion 1 + pending 1 (admin) + period 4 + products 1 = **20** for an admin, 19 for an assistant; the urgent watch can read the bell feed's own announcements (`notification_feed.dart:339`), giving 19 and 18. Recent Activity, the chart, the trends and the glance load only when "All details" opens, so a return to Home costs **0 gets** (today at least 23).

## 3. Specification (all values as named constants)

**The phone signal.** One getter, `AppLayout.isPhone(context)`: width below `AppBreakpoints.compact` (600), or height below a new `AppBreakpoints.phoneLandscapeHeight` (500) while the width is below `expanded` (1024). So a 390 x 844 phone in landscape (844 x 390) stays a phone; 768 x 1024 and 1024 x 768 tablets and a short desktop window (1200 x 550) do not. It replaces the raw `600` and `1024` at `:2167-2168`.

New `PhoneShellMetrics` in `lib/theme/app_dimens.dart` (like `WizardMetrics`), colours only from `context.colors` roles:

| Piece | Measure |
|---|---|
| Bottom bar | 64 high plus `MediaQuery.viewPadding.bottom`; 5 equal slots (72 each at 360, 78 at 390); icon 24; label f12, one line (the likely longest Kiswahili, "Nyumbani" for Home, is about 52 px); fill `surface`, top border `borderStrong` 1 px; selected: icon and label `primary` with a 56 x 32 pill `primary` at 12% |
| "+" | circle 56, fill `accent`, icon 28 `onAccent`, elevation `AppElevation.e6`; raised so 20 px sit above the bar's top edge; the whole slot (72 x 64 plus the overlap) is the tap target; no label, semantics "Record" |
| Keyboard | the bar is not drawn while `MediaQuery.viewInsetsOf(context).bottom > 0`; checked on the owner's phone, since mobile browsers report the keyboard differently |
| Top bar | 56 high, padding 16; avatar 40 (`profileAvatarBar` grows from 32); greeting f13 `textMuted` over name f16 bold, both one line with ellipsis; bell and Help 48 x 48 |
| Page | side padding 16, section gap 16, section titles f15 semibold with "View all" / "All details" as 48-high text buttons |
| Today card | padding 16, radius `AppRadius.r16`, fill `brandSurface`, text `onBrandSurface`; Sales f28 bold in a `FittedBox(scaleDown)`; 3 (or 2) mini stats in equal `Expanded` columns, value f15 bold scaled down to fit (an 8-digit amount at 360), label f12; the date chip 36 high in a 48 target |
| Quick access | 4 tiles in a row, 8 apart: 76 x 92 at 360, 83 x 92 at 390; icon circle 44, label f12, at most 2 lines, centred |
| Go to | horizontal list 96 high; item 72 wide; circle 56 with icon 24; label f12, 2 lines; the fifth item cut at the edge shows it scrolls |
| Needs attention | up to 3 rows of 56: icon, one-line text, count chip, chevron; fill `warningBannerFill`; hidden when empty (no empty state) |
| More page | a grid of round icons: 4 per row at 360 and 390, circle 56, label f12 2 lines, cell 80 x 100 |
| "+" sheet | drag handle, title f16, 4 rows of 64 (icon circle 40, label f16, hint f13), bottom padding `viewPadding.bottom` |

**Safe areas and the address bar.** Every bottom element adds `viewPadding.bottom`; the top bar sits under a `SafeArea(bottom: false)`. The mobile address bar resizing the page moves only the bar, which is pinned to the bottom. The subscription pill (`Positioned(top: 56)` at `:1476`) moves under the top bar on phones.

**Landscape phones** are phones (above): the bar stays; the Today card's 3 stats and the 4 tiles keep one row; the page scrolls.

**Kiswahili, Dark Mode, the four themes.** New labels go through the ARB (drafts). Labels allow 2 lines where shown; numbers scale down instead of overflowing. Only roles from `context.colors` (no new literals), so Dark Mode and the four themes follow; the owner's later style changes are made in `PhoneShellMetrics` and the roles.

**Accessibility.** Every target at least 48 x 48; each tile, shortcut and bar item has a `Semantics` label (the bar items `selected`); focus order: top bar, Today card, Quick access, Go to, Needs attention, then the bar; text scales up to 1.3 without overflow (the test in B section 10).

## 4. The five places and the Go to row

| Bar | First screen | Notes |
|---|---|---|
| Home | the new phone home | the only place with the greeting top bar |
| Sales | `SalesScreen(asTab: true)` | its own AppBar, no back arrow |
| + | the sheet (not a place) | Record Sale, Record Visit, Record Payment, Add Client (today's labels) |
| Stock | `ProductsScreen(asTab: true)` (recommended: the shelf people sell from); Stock Store from Go to and More | or Stock Store, the drawer's "Stock" (`:2249`): owner question 3 |
| More | the new More page (D5) | round icons, by role |

Quick access "View all" adds: Add Product (admin), Add Batch (from a product), Add Expense (`showAddTransactionScreen`).

| Go to, in order | Admin | Assistant |
|---|---|---|
| 1-5 | Products, Clients, Debts, Reports, Expenses | Products, Clients, Debts, Reports, Expenses |
| 6-8 | Stock Store, Services, Payments | Stock Store, Services, Payments |

More, admin: Services, Payments, Transactions, Reports, Insights, Team Members, Facilities, Settings, Trash, Export, Business Hours, Subscription, Activity log, Help. Assistant: Services, Payments, Transactions, Reports, Insights, Settings, Help. (Team Members, Facilities and Activity log stay in the profile drawer too.)

## 5. The tablet

| | 768 x 1024 portrait | 1024 x 768 landscape |
|---|---|---|
| Shell | AppBar with the hamburger and drawer (`:1104`, below 1024) | permanent sidebar 250 (collapsible to 72) and top bar |
| Grid | 3 columns (`:1273`, width over 700) | 3 columns (about 742 px) |
| Forms | full pages (below 900) | 60% modal, about 614 px |
| Lists | 7-8 flex columns; a 340-380 px panel beside the list on tap | the same; about 644 px left with the panel |

With the phone signal above, both keep today's layout (D1). Owner decision: keep portrait as it is (recommended for the first test), or give portrait the permanent collapsed sidebar (72) instead of the hamburger. The installed app is locked to portrait (`web/manifest.json:9`); a browser tab is not.

## Questions only the owner can answer

1. Back on Home: do nothing (recommended) or ask "Leave VetBiz Pro?".
2. The date chip: today offers periods (Today, This Week, This Month, This Year, `:1215`), not a chosen day. Keep the periods (recommended), or add "pick a day" (cheap: one day's summaries)?
3. Stock tab: Products (recommended) or Stock Store.
4. "Owed": everything owed now (recommended, no new reads) or credit given in the period (new data).
5. On "All details": also the chart and Recent Activity, below the rows (recommended)?
6. Labels: keep "Record Visit" and "Record Payment" (recommended, unchanged English) or the owner's "Record service" and "Take payment"; "Expenses" for the Transactions screen?

OWNER DECISION: PENDING
