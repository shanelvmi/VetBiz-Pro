# K0: Dark Mode for the four colour themes

Batch K0 (RUNBOOK2 section 7), a DESIGN STOP: no code is changed. K1 implements this once the last line says APPROVED.
Inputs: RUNBOOK2 D11 (System, Light, Dark; dark for every colour theme; receipts, PDFs and the thermal printer always light), `docs/design/themes.md` (T1, approved), the code at `d560f08`. The visual mock is `docs/design/dark_preview.html` (open it in a browser).
Every number below was computed (WCAG 2.1 relative luminance; translucent roles composited over their fill first; HSL as Flutter's `HSLColor`, rounded per channel). None is estimated.

## 1. Current state

- **`AppTheme.build(theme, brightness)`** (`lib/theme/app_theme.dart:15`) already takes a `Brightness`, but uses it only to seed `ColorScheme.fromSeed(..., brightness)`. It then overrides `primary`, `secondary` and `surface` with the light brand values, sets `scaffoldBackgroundColor` to `theme.background`, and registers `AppColors.fromTheme(theme)`, which has no brightness. Passing `Brightness.dark` today would give a dark Material scheme with light page, light cards and dark text roles: unusable.
- **`main.dart:109`** always calls `AppTheme.build(colorTheme, Brightness.light)`. There is no `darkTheme` and no `themeMode`, so `MaterialApp` is always light.
- **The dialog's placeholder** (`lib/screens/settings/ui_settings_dialog.dart:63`): a `ListTile` "Dark Mode" with the subtitle `uiSettings_comingSoon` and `const Switch(value: false, onChanged: null)`, so it is disabled and saves nothing.
- **Stored settings:** `UiSettingsProvider` (`lib/providers/ui_settings_provider.dart`), SharedPreferences, device-local, not cleared by `resetAllUserProviders`: `ui_color_theme` (theme id, legacy `kilimanjaro` rewritten to `pasture`), `ui_layout_fixed`, `ui_language`.
- **Role use today:** `context.colors.primary` 743 uses, `onPrimary` 268, `accent` 123, `textPrimary` 132, `surface` 198, `background` 139. Raw colours left: 8 KEEP allowlist entries (A1, A2, A4, A9, A18, A20, A21, A23-24), 24 `Colors.transparent`.

## 2. The problem, and options

In light, `primary` is both a **fill** (the sidebar, buttons, the login gradient, headers, with `onPrimary` white on it) and **ink** (text, icons, borders on cards). In dark that cannot be one colour: white on the fill needs luminance <= 0.183, while ink needs 0.26 to 0.29 to reach 4.5 on the dark `surfaceMuted`. No single value passes both checks.

- **Option 1 (recommended): Material 3's split, plus one brand fill role.** In dark, `primary` becomes a light tone of the theme's hue (ink, and the fill of buttons and chips with dark `onPrimary` ink, as Material 3 dark does). A new role pair **`brandSurface` / `onBrandSurface`** keeps the deep brand colour for the large brand areas (sidebar, login and register gradients, page headers), so the app still looks like its theme. **`onAccent`** (new) is the ink on accent fills, replacing `textPrimary` there (white on amber fails in dark). In light the three new roles equal `primary`, `onPrimary` and `textPrimary`, so light does not change. Cost: K2 to K5 move the brand-area uses (sidebar, gradients, headers; roughly the 186 `color:`/`backgroundColor: context.colors.primary` lines are the candidates, most stay as they are).
- **Option 2: keep `primary` deep in dark, add an ink role `primaryInk`.** The fills keep white text. But every text, icon and border use of `primary` (most of the 743) has to move to `primaryInk`, a much larger migration with a high risk of misses (today's light primaries on the dark surface measure 1.17 to 2.20, on the background 1.28 to 2.48).
- **Option 3: Material's dark tonal palette** (`ColorScheme.fromSeed(brightness: dark)` for everything). Rejected: it ignores the T1 derivation, gives every theme the same grey-blue surfaces, and leaves the 65 `AppColors` roles unset.

## 3. Proposed dark values, every role (option 1)

`AppColors.fromTheme(theme, {Brightness brightness = Brightness.light})`: the light path is T1's code, untouched (Pasture light stays value for value). The dark path applies the rules below. H, S, L = the theme primary's HSL; "lift to X on Y" = keep H and S, raise L in 0.01 steps until the contrast on Y reaches X.

**Neutral surfaces and text (rule, then values)**

- `background` = HSL(H, min(S, 0.25), 0.075); `surface` = same at L 0.115; `surfaceMuted` = same at L 0.155 (a hint of the theme's hue, so the dark themes stay distinguishable).
- Text: `textStrong` #FFFFFF, `textPrimary` white 87%, `textSecondary` white 70%, `textSoft` #BDBDBD, `textMuted` #9E9E9E (the darkest grey from #9E9E9E reaching 4.5 on `surfaceMuted`), `textHint` #808080 (3.0 on `surface`), `textDisabled` white 38%.
- Lines: `borderStrong` white 30%, `border` white 16%, `divider` white 10%. `scrim` and `shadow` stay #000000 (section 4).

**Brand-linked (per theme)**

- `primary` = HSL(H, clamp(S, 0.35, 0.6), L), lifted to 4.5 on `surfaceMuted`. `onPrimary` and `onAccent` = the dark `background`; `onPrimaryMuted` = background 85% (72% failed: 3.70 to 3.77); `onPrimarySubtle` = background 24%.
- `accent` unchanged (it already passes on dark: 6.76 to 10.07).
- New `brandSurface` = the theme's light `primary`; `onBrandSurface` = white.
- The six T1 derived roles: `sidebarHover`/`sidebarPress` sit on `brandSurface`, so the T1 rule applied to it gives **the same values as light**; `brandTealGlow` (glow on the login gradient, which moves to `brandSurface`) also stays as light; `brandTeal` (links, Total Products, operator badge) = the T1 value lifted to 4.5 on `surface`; `quickActionTintPrimary` = HSL(H, 0.30, L) with L lowered from 0.17 until the dark `primary` reaches 4.5 on it (0.17 gave 4.14 to 4.38); `quickActionTintAccent` = HSL(accent H, 0.45, 0.16).

| Role | Pasture | Clinic | Harvest | Ledger |
|---|---|---|---|---|
| `background` | #0E1718 | #0E1318 | #18120E | #0E1218 |
| `surface` | #162325 | #161E25 | #251C16 | #161C25 |
| `surfaceMuted` | #1E2F31 | #1E2831 | #31251E | #1E2531 |
| `primary` | #509EA7 | #4992D1 | #B58463 | #708DBA |
| `accent` | #FFB200 | #5BC0EB | #E3A72F | #8B9CFF |
| `onPrimary`, `onAccent` | #0E1718 | #0E1318 | #18120E | #0E1218 |
| `onPrimaryMuted` / `onPrimarySubtle` | bg 85% / 24% | bg 85% / 24% | bg 85% / 24% | bg 85% / 24% |
| `brandSurface` (new; light = primary) | #2F5D62 | #0F4C81 | #4A3426 | #1E293B |
| `onBrandSurface` (new; light = onPrimary) | #FFFFFF | #FFFFFF | #FFFFFF | #FFFFFF |
| `sidebarHover` (= light) | #00796B | #005A78 | #64391D | #013559 |
| `sidebarPress` (= light) | #00695C | #004F68 | #583219 | #012D4A |
| `brandTealGlow` (= light) | #7EE8CB | #7EDEE8 | #DDAA89 | #7ECEE8 |
| `brandTeal` | #419588 | #1195BA | #B07A58 | #518CAE |
| `quickActionTintPrimary` | #1B2F32 | #1B2732 | #32241B | #1B2332 |
| `quickActionTintAccent` | #3B3016 | #16303B | #3B2F16 | #161C3B |

**Semantic roles (the same in every theme).** Rule: the light value lifted to 3.0 (icons, chips: base roles) or 4.5 (text: `Strong`, `Deep`, `Text` roles) on the lightest dark `surfaceMuted` of the four themes, so one value serves all. Light -> dark:
`success` #4CAF50 (unchanged), `successStrong` #388E3C -> #42A847, `danger` #F44336, `dangerAccent` #FF5252, `dangerSoft` #EF5350 (unchanged), `dangerStrong` #D32F2F -> #E17272, `dangerDeep` #B71C1C -> #E96F6F, `warning` #FF9800, `warningStrong` #EF6C00 (unchanged), `info` #2196F3 (unchanged), `infoStrong` #1976D2 -> #4597E9, `infoNote` #78909C (unchanged), `infoNoteText` #546E7A -> #7B97A4, `infoNoteTextSoft` #607D8B -> #7E99A6, `trendUp` #10B981, `trendDown` #EF4444 (unchanged), `warningBannerText` #C77800 -> #D68100, `warningBannerFill` #FFF6E7 -> #302412, `dangerSurface` #FFF1F0 -> #321515. Note: in dark `dangerDeep` is lighter than `dangerStrong` (the lift order); both are text roles and both pass.

**One-off chart and category roles (the same in every theme), same lift to 3.0:**
`chart1` #3D5A80 -> #5177A9, `chart2` #6A4C93 -> #8667B0, `chart3` #B56A00, `chart4` purple -> #BC37D3, `chart5` blueGrey #607D8B, `chart6` teal #009688, `chart7` indigo -> #606FC7, `chart8` #FFA000, `chart9` #FF5722 (unchanged where no arrow); `chartService1-4` #5C7C99, #8FA998, #B98B6F, #9B8AA6 (unchanged); `roleOwner` indigo -> #606FC7, `roleOwnerStrong` #303F9F -> #8490DA, `roleCoAdmin` #009688, `roleCoAdminStrong` #00796B -> #00A794, `roleAssistant` #607D8B, `roleAssistantStrong` #455A64 -> #7E99A6, `rolePlatformAdmin` #673AB7 -> #8861CD. The role chips keep their pattern (a light fill of the base colour, the Strong shade as label).

That is all 65 roles plus the 3 new ones (68), each with a dark value in every theme.

## 4. Places that are not role-driven (each needs a decision)

| Place | Today | Proposal |
|---|---|---|
| Logo `assets/vetbiz_pro_logo.png` (dashboard header `dashboard_screen.dart:2883`, loading screen, business profile default) | PNG on light | Put it on a `brandSurface` or white rounded plate in dark (K2); no second logo file unless the owner provides one |
| `assets/background.jpeg` (login, register, `auth_background.dart`) | photo with a brand gradient over it | Keep the photo; the gradient moves to `brandSurface` (K4) |
| Charts (`fl_chart`: dashboard, insights, operator overview) | chart roles, grid lines and labels | Roles as section 3; grid lines `divider`, axis labels `textMuted`; tooltips `surfaceMuted` (K5) |
| Insights service palette | `primary`, `chartService1`, `accent`, `chartService2-4` | Follows the roles; the dark `primary` passes 3.0 on surface (5.06 to 5.22) |
| Loading screen (`vetbiz_loading_indicator.dart:41`) | `AppPalette.background`, shown before settings load | Stays Pasture LIGHT (T1 decision). It shows before the saved mode is read, so a dark device sees a short light flash; accepted, noted for K2 |
| Maintenance screen (`maintenance_gate.dart`) | `background`, `primary`, `textSoft`, `textMuted` roles | Role-driven: follows dark with no change; checked in K2 |
| Shadows and scrims (57 uses) | `shadow`/`scrim` black at low alpha | Stay black. Elevation in dark is shown by the lighter `surface`/`surfaceMuted`, not by the shadow; K3 checks that cards stay distinguishable |
| Receipt previews (`receipt_preview_screen.dart`, `service_receipt_preview_screen.dart`) incl. `PdfPreview`, `ReceiptPalette`, `PdfPalette` | `AppPalette` and receipt palettes | ALWAYS LIGHT (D11): wrap the preview body in a `Theme` built with `Brightness.light` for the chosen colour theme, so its text roles are light too. Printed receipts and PDFs (`receipt_pdf_service.dart`, daily report PDF) are not Flutter widgets and do not change |
| Thermal printer (`printer_settings_screen.dart`, `receipt_printer_service.dart`) | no on-screen preview; ESC/POS bytes | Nothing to change; the settings screen itself follows dark |
| Material widgets: date picker, dialogs, snack bars, switches, chips, menus, text fields | `AppTheme.build` sets some (date picker, buttons, inputs), Material sets the rest from `colorScheme` | `AppTheme.build` must set `colorScheme` from the dark roles (primary, onPrimary, secondary = accent, surface = surface, surfaceContainer* = surfaceMuted, error = danger) and use `surface`, not `background`, for the date picker's foreground; inputs' enabled border = `borderStrong` |
| Plugin widgets: `flutter_typeahead` suggestion box, `flutter_speed_dial`, `smooth_page_indicator`, `flutter_spinkit`, `flutter_markdown` | colours from `Theme.of(context)` or passed in | Check each in K4; pass role colours where a plugin uses its own default |
| KEEP raw colours A1 orange 900, A2 blue 900 (text), A4 teal 300, A9 red dot, A18, A20, A21, A23-24 | fixed hex | On the dark surface A1 (text) measures 4.26 to 4.52 and A2 (text) 1.87 to 1.98, both under 4.5: give them roles in K3/K4 (`warningStrong`, `infoStrong`); the icons and dots pass 3.0 or are checked in place |

## 5. Contrast in dark, computed (every theme)

Text roles on the dark surface roles (surface / surfaceMuted / background; **bold** = below the threshold):

| Text role (threshold) | Pasture | Clinic | Harvest | Ledger |
|---|---|---|---|---|
| `textStrong` (4.5) | 16.14 / 13.94 / 18.19 | 16.85 / 14.97 / 18.67 | 16.72 / 14.85 / 18.56 | 17.12 / 15.39 / 18.78 |
| `textPrimary` (4.5) | 12.44 / 10.92 / 13.88 | 12.99 / 11.65 / 14.15 | 12.83 / 11.59 / 14.09 | 13.11 / 11.98 / 14.23 |
| `textSecondary` (4.5) | 8.52 / 7.64 / 9.24 | 8.76 / 8.08 / 9.40 | 8.75 / 8.03 / 9.39 | 8.90 / 8.25 / 9.46 |
| `textSoft` (4.5) | 8.59 / 7.42 / 9.68 | 8.97 / 7.97 / 9.94 | 8.90 / 7.91 / 9.88 | 9.11 / 8.19 / 9.99 |
| `textMuted` (4.5) | 6.02 / 5.20 / 6.79 | 6.29 / 5.59 / 6.97 | 6.24 / 5.54 / 6.93 | 6.39 / 5.75 / 7.01 |
| `textHint` (3.0) | 4.09 / 3.53 / 4.61 | 4.27 / 3.79 / 4.73 | 4.23 / 3.76 / 4.70 | 4.33 / 3.90 / 4.75 |
| `textDisabled` (4.5) | **3.52 / 3.34 / 3.57** | **3.57 / 3.44 / 3.59** | **3.53 / 3.42 / 3.57** | **3.55 / 3.47 / 3.57** |

Brand fills and special pairs:

| Pair (threshold) | Pasture | Clinic | Harvest | Ledger |
|---|---|---|---|---|
| `onPrimary` on `primary` (4.5) | 5.88 | 5.61 | 5.70 | 5.55 |
| `onPrimaryMuted` on `primary` (4.5) | 4.77 | 4.63 | 4.66 | 4.61 |
| `onPrimarySubtle` on `primary` (3.0) | **1.50** | **1.49** | **1.50** | **1.51** |
| `primary` on background / surface / surfaceMuted (4.5) | 5.88 / 5.22 / 4.51 | 5.61 / 5.07 / 4.50 | 5.70 / 5.13 / 4.56 | 5.55 / 5.06 / 4.55 |
| `accent` on surface (3.0) | 8.93 | 8.17 | 7.83 | 6.76 |
| `onAccent` on `accent` (4.5) | 10.07 | 9.05 | 8.69 | 7.42 |
| `onBrandSurface` on brandSurface / sidebarHover / sidebarPress (4.5) | 7.34 / 5.32 / 6.61 | 8.86 / 7.68 / 9.06 | 11.60 / 9.79 / 11.14 | 14.63 / 12.69 / 14.23 |
| `brandTealGlow` on `brandSurface` (4.5) | 4.99 | 5.69 | 5.63 | 8.28 |
| `brandTeal` on `surface` (4.5) | 4.52 | 4.84 | 4.59 | 4.66 |
| `primary` on `quickActionTintPrimary` (4.5) | 4.53 | 4.57 | 4.59 | 4.66 |
| `textPrimary` on `quickActionTintAccent` (4.5) | 10.21 | 10.82 | 10.32 | 12.75 |
| `warningBannerText` on `warningBannerFill` (4.5) | 5.05 | 5.05 | 5.05 | 5.05 |
| `dangerDeep` on `dangerSurface` (4.5) | 5.56 | 5.56 | 5.56 | 5.56 |

Semantic and one-off roles, the LOWEST ratio over surface, surfaceMuted and background in all four themes (all pass): `success` 5.02, `danger` 3.79, `dangerAccent` 4.37, `dangerSoft` 4.00, `warning` 6.47, `info` 4.46, `infoNote` 4.16, `trendUp` 5.50, `trendDown` 3.71 (3.0); `successStrong` 4.60, `dangerStrong` 4.55, `dangerDeep` 4.63, `warningStrong` 4.52, `infoStrong` 4.55, `infoNoteText` 4.52, `infoNoteTextSoft` 4.64, `warningBannerText` 4.65 (4.5); charts `chart1` 3.03, `chart2` 3.04, `chart3` 3.34, `chart4` 3.07, `chart5` 3.19, `chart6` 3.80, `chart7` 3.05, `chart8` 6.83, `chart9` 4.41, `chartService1` 3.19, `chartService2` 5.51, `chartService3` 4.64, `chartService4` 4.37 (3.0); roles `roleOwner` 3.05, `roleCoAdmin` 3.80, `roleAssistant` 3.19, `rolePlatformAdmin` 3.08 (3.0), `roleOwnerStrong` 4.64, `roleCoAdminStrong` 4.62, `roleAssistantStrong` 4.64 (4.5).

What was changed to pass, and what stays a known fail:
- Changed while computing: `onPrimaryMuted` 72% -> 85% (3.70 to 3.77 -> 4.61 to 4.77); `quickActionTintPrimary` L 0.17 -> 0.15 (4.14 to 4.38 -> 4.53 to 4.66); every semantic, chart and role colour lifted as listed in section 3; `onAccent` added (the dark `textPrimary`, white 87%, on the accents: 1.67 to 2.27).
- Known, kept: `textDisabled` 3.34 to 3.59 (disabled controls are exempt in WCAG; light today is 1.88, so dark is better); `onPrimarySubtle` 1.49 to 1.51 (sidebar dividers, not text; light 1.80 to 2.17). Both held in the test at "no worse than computed here minus 0.2".
- Thin passes pinned by the test: `primary` on `surfaceMuted` (4.50 Clinic), `chart1` 3.03, `chart2` 3.04.

## 6. The System, Light, Dark setting

- **Stored:** a new SharedPreferences key `ui_theme_mode` in `UiSettingsProvider`, values `system`, `light`, `dark` (stored English ids, never labels), device-local, not cleared by `resetAllUserProviders`. An unknown or missing value reads as the default.
- **Default:** recommended `light` until K5 is done (a device whose platform is dark would otherwise see unfinished dark screens on its first start after K1); the owner can switch the default to `system` after K5.
- **App:** `MaterialApp(theme: AppTheme.build(colorTheme, Brightness.light), darkTheme: AppTheme.build(colorTheme, Brightness.dark), themeMode: ...)`. With `system`, Flutter follows `MediaQuery.platformBrightnessOf` and switches live when the platform changes.
- **Web:** the platform brightness is the browser's `prefers-color-scheme`, which Flutter web reads at start and on change; no extra code. Chrome on Windows follows the Windows app mode.
- **Dialog:** the Dark Mode switch becomes a three-way choice (System, Light, Dark) with ARB labels `uiSettings_themeModeSystem/Light/Dark` (Kiswahili draft); `uiSettings_comingSoon` is then unused and retired.

## 7. Test plan (K1)

1. **Every dark role exists:** for every theme, `fromTheme(theme, brightness: dark)` gives all 68 roles, and `copyWith()` / `lerp(..., 0)` keep them (like T1's `theme_contrast_test.dart`).
2. **The dark values:** the per-theme table of section 3 pinned exactly; the semantic and one-off values pinned; the rules tested with a made-up theme (the lift reaches its threshold; `background` < `surface` < `surfaceMuted` in luminance).
3. **Contrast in dark, all themes, computed:** every pair of section 5 at its threshold; the known fails held at "computed here minus 0.2" with their reason.
4. **Pasture light is unchanged value for value:** the existing `tokens_test.dart` groups, the R2 pins and T1's `theme_derivation_test.dart` / `theme_contrast_test.dart` keep passing unchanged; `fromTheme(theme)` with no brightness equals `fromTheme(theme, brightness: light)` for every role in every theme; the three new roles equal `primary`, `onPrimary`, `textPrimary` in light.
5. **The setting:** `ui_theme_mode` saved and restored after a provider restart (SharedPreferences mock) for each of the three values; an unknown value gives the default; the dialog shows the three choices and choosing Dark rebuilds the app with the dark `AppColors`.
6. `flutter analyze` 0 issues, all tests passed, the guard at zero.

## 8. K1 and the visual-fix batches K2 to K5

- **K1:** the dark `AppColors`, the three new roles (light values = today's), `AppTheme.build` for dark (section 4, Material widgets), the setting, the dialog, the tests. No screen moved yet. Default `light`, so nothing changes for anyone who does not choose Dark.
- **K2 dashboard and sidebar (HARD STOP):** sidebar, header and drawer to `brandSurface`/`onBrandSurface`; quick-action cards; the logo plate; the loading and maintenance screens checked; the trial pill and the bell.
- **K3 lists and cards (HARD STOP):** Sales, Products, Stock Store, Services, Debts, Payments, Team Members, Facilities; chips, status pills, role chips; card separation with shadows; KEEP A1/A2 to roles.
- **K4 forms and dialogs (HARD STOP):** Add Sale and the other forms, dialogs, UI Settings, login and register (gradient to `brandSurface`), the plugin widgets (typeahead, speed dial, page indicator, markdown); `accent` fills to `onAccent` ink.
- **K5 reports, charts and the receipt previews (HARD STOP):** daily report screens, insights and dashboard charts (grid, labels, tooltips), the operator overview; the receipt previews wrapped in a light `Theme` (D11) and confirmed unchanged.
- Each K batch fixes colour problems only, no layout changes, and the owner checks the batch's screens in all four themes in Light and Dark.

## 9. Rollout and rollback

K1 ships with the default `light`, so it is invisible until someone chooses Dark. Rollback: revert the K commits; a saved `ui_theme_mode` is then ignored (an unread key), and the app is light as today. No server, rules or index change.

OWNER DECISION: APPROVED option 1 (the Material 3 split with brandSurface, onBrandSurface and onAccent), default mode Light until K5, the logo plate, the loading-screen flash accepted, and K1 keeps the coded rule's values where they differ from the table by rounding (updating the table and listing each difference). K2 to K4 are checked in Dark for Pasture and Harvest; all four themes at K5.