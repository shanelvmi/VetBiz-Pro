# T0: the four colour themes (Pasture, Clinic, Harvest, Ledger)

Batch T0 (RUNBOOK2 section 6), a DESIGN STOP: no code is changed. T1 implements this once the last line says APPROVED.
Inputs: RUNBOOK2 D10 (the chosen colours), D11 (Dark Mode later; receipts stay light), `docs/design/parked_values.md` (the colour classes), `lib/theme/app_colors.dart` at `0ba9e4f`. The visual mock is `docs/design/theme_preview.html` (open it in a browser).
Every number below was computed (WCAG 2.1 relative luminance; translucent roles composited over the surface first; colour distance is CIEDE2000, "dE"). None is estimated.

## 1. Current behaviour

- `AppColorTheme` (`lib/theme/app_palette.dart:32`) has `id`, `name`, `primary`, `accent`, `available`. Only `kilimanjaro` (#2F5D62 / #FFB200) is selectable; `serengeti` and `victoria` are `available: false` ("Coming soon").
- The background is NOT per theme: `AppColors.fromTheme` (`app_colors.dart:223`) and `AppTheme.build` (`app_theme.dart:22`) both read the constant `AppPalette.background` (#FDFDF9).
- `AppTheme.build` seeds Material's `ColorScheme.fromSeed` with the primary, then sets primary, secondary (= accent) and surface (= background). The Material tonal colours (chips, switches, focus) therefore already follow the primary; Pasture keeps today's seed, so it does not change.
- Stored choice: `UiSettingsProvider` (`lib/providers/ui_settings_provider.dart:15`), SharedPreferences key `ui_color_theme`, device-local, not cleared by `resetAllUserProviders`. On load, `AppColorTheme.byId(saved)` is used only if `available`; an unknown id falls back to `kilimanjaro`.
- Shown names: `_themeName` in `lib/screens/settings/ui_settings_dialog.dart:192`, ARB keys `uiSettings_themeKilimanjaro/Serengeti/Victoria`.
- 13 direct `AppPalette.*` uses outside `lib/theme` bypass the theme (section 8).

## 2. The four themes (D10, exact)

| id | Name | primary | accent | background | onPrimary |
|---|---|---|---|---|---|
| `pasture` (default) | Pasture | #2F5D62 | #FFB200 | #FDFDF9 | #FFFFFF |
| `clinic` | Clinic | #0F4C81 | #5BC0EB | #F6F9FC | #FFFFFF |
| `harvest` | Harvest | #4A3426 | #E3A72F | #FBF7F0 | #FFFFFF |
| `ledger` | Ledger | #1E293B | #8B9CFF | #F8FAFC | #FFFFFF |

Pasture is today's look exactly (primary, accent and background are today's `AppPalette` values), so Pasture changes by nothing.

D10's checks, recomputed: white on primary 7.34, 8.86, 11.60, 14.63 (need 4.5); primary on background 7.19, 8.38, 10.86, 13.98 (4.5); dark ink on accent, with `textPrimary` (black87) 9.69, 8.61, 8.39, 7.16 and with black 11.62, 10.18, 9.83, 8.30 (4.5; D10's own figures, 8.2 to 5.8, are lower but also pass); accent on primary 4.06, 4.30, 5.43, 5.78 (3.0). All pass.

## 3. Options for the brand-linked roles

- **Option 1 (recommended): one HSL rule per role.** Each role = the theme's primary (or accent) with a fixed hue shift and a saturation and lightness offset (or absolute value), with the offsets taken from Pasture so that Pasture reproduces its value EXACTLY. Two guards keep the other themes sane (below). A new theme gets all six roles with no extra work. Cost: the guards are a little code, and the test must prove Pasture exact.
- **Option 2: a hand-picked table.** Each theme lists its six values. Simplest code, Pasture trivially exact, but every future theme needs six hand-made colours and nothing guarantees they behave.
- **Option 3: Material's tonal palette** (`primaryContainer`, ...). Rejected: it changes every Pasture value.

## 4. Brand-linked roles (derived per theme): Option 1 rules and results

Audit: from parked_values.md A5, A6, A10, A11, A16, A17; from `app_colors.dart` the base roles `primary`, `accent`, `background` (taken from the theme as given). Nothing else in `AppColors` follows the brand: `roleCoAdmin`/`chart6` teal and the other chart and role colours are Material category colours (section 6). `surface`, `surfaceMuted`, the text roles (except `textMuted`, section 7) and the `onPrimary*` whites are neutral (the same in every theme).

H = hue (degrees), S and L = HSL saturation and lightness (0 to 1); `+` is an offset, `=` an absolute value; results rounded per channel.

| Role (where it is used) | Rule | Pasture (= today) | Clinic | Harvest | Ledger |
|---|---|---|---|---|---|
| `sidebarHover` (drawer item hover) | primary, H -12.82, S +0.648, L -0.047 | #00796B | #005A78 | #64391D | #013559 |
| `sidebarPress` (platform-admin button press) | primary, H -13.31, S +0.648, L -0.078 | #00695C | #004F68 | #583219 | #012D4A |
| `brandTeal` (login gradient, links, Total Products, operator badge) | primary, H -14.88, S +0.04, L +0.116 | #3E8E82 | #1195BA | #754F37 | #2F5165 |
| `brandTealGlow` (login glow) | primary, H -22.3, S = 0.697, L = 0.702 | #7EE8CB | #7EDEE8 | #DDAA89 | #7ECEE8 |
| `quickActionTintPrimary` (Record Visit card) | primary, H -24.34, S = 0.302, L = 0.916 | #E3F0EC | #E3EFF0 | #F0E8E3 | #E3EDF0 |
| `quickActionTintAccent` (Add Product card) | accent, H -4.2, S = 0.85, L = 0.92 | #FCEFD9 | #D9F4FC | #FCEED9 | #D9E1FC |

- **Warm guard** (primary-derived roles only): if the shifted hue lands in 330 to 40 degrees (the danger-red band), the role keeps the primary's own hue and S is capped at 0.55. Without it, Harvest's hover was #571001 (a dark red, dE 23.5 from danger red) and its `brandTeal` #753F37 (dE 14.9). Pasture, Clinic and Ledger are not affected.
- **Visibility floor** (`sidebarHover` and `sidebarPress` together): if the hover is less than dE 8 from the primary, both get the same extra L in 0.01 steps until it is not. Pasture (dE 14.0) and Clinic (9.6) get 0; Harvest +0.08 (5.1 -> 8.6), Ledger +0.05 (5.4 -> 8.4). The table above includes both guards.
- **A4** (the empty-team icon, teal 300, `manage_assistants_screen.dart`) is brand-linked but a KEEP raw value with no role: recommended to stay teal in every theme (one icon); a role can come later.
- **Names after the old green** (renaming is optional; no value changes): `primaryDeepGreen`, `warmAmber`, `offWhite` (`main.dart:93-95`, `app_theme.dart:20-22`), `_deepGreen` (`main.dart:760`), `brandTeal`/`brandTealGlow` themselves (teal only in Pasture), the AppPalette doc comment "Kilimanjaro Green".

## 5. Semantic roles (the same in every theme): contrast on each background

| Role | Value | white | Pasture | Clinic | Harvest | Ledger |
|---|---|---|---|---|---|---|
| success | #4CAF50 | 2.78 | 2.73 | 2.63 | 2.60 | 2.66 |
| successStrong | #388E3C | 4.12 | 4.04 | 3.89 | 3.85 | 3.93 |
| danger | #F44336 | 3.68 | 3.61 | 3.49 | 3.45 | 3.52 |
| dangerAccent | #FF5252 | 3.19 | 3.13 | 3.02 | 2.99 | 3.05 |
| dangerSoft | #EF5350 | 3.49 | 3.42 | 3.30 | 3.26 | 3.33 |
| dangerStrong | #D32F2F | 4.98 | 4.88 | 4.71 | 4.66 | 4.76 |
| dangerDeep | #B71C1C | 6.57 | 6.44 | 6.22 | 6.15 | 6.28 |
| warning | #FF9800 | 2.16 | 2.11 | 2.04 | 2.02 | 2.06 |
| warningStrong | #EF6C00 | 3.08 | 3.02 | 2.92 | 2.89 | 2.95 |
| info | #2196F3 | 3.12 | 3.06 | 2.96 | 2.93 | 2.99 |
| infoStrong | #1976D2 | 4.60 | **4.51** | **4.36** | **4.31** | **4.40** |
| infoNote | #78909C | 3.35 | 3.29 | 3.17 | 3.14 | 3.20 |
| infoNoteText | #546E7A | 5.40 | 5.30 | 5.11 | 5.06 | 5.16 |
| infoNoteTextSoft | #607D8B | 4.37 | 4.29 | 4.14 | 4.09 | 4.18 |
| trendUp | #10B981 | 2.54 | 2.49 | 2.40 | 2.38 | 2.42 |
| trendDown | #EF4444 | 3.76 | 3.69 | 3.56 | 3.52 | 3.60 |
| warningBannerText | #C77800 | 3.43 | 3.37 | 3.25 | 3.22 | 3.28 |
| warningBannerText on warningBannerFill at 0.92 | | | 3.23 | 3.20 | 3.21 | 3.20 |

Also `dangerSurface` #FFF1F0 with `dangerDeep` text: 5.97 (no background involved). Reading: the new backgrounds lower every pair by at most 0.2. **Only one pair moves from pass to fail:** `infoStrong` as text on the background (4.51 in Pasture; 4.31 to 4.40 elsewhere). Fix: test it on `surface` (cards, 4.60), where it is used as text; if a use on the bare background is found in T1, switch that use to `infoNoteText` or ask the owner about blue 800 #1565C0 (5.38 to 5.64 everywhere; changes Pasture, so not without the owner). The rest already fail at 4.5 in Pasture today (they are icon, chip, chart or large-text colours); they are kept as they are and listed in the test as known (section 10), never as text-role passes. **At 3:1 (icons), three pairs move from pass to fail by at most 0.13:** `info` (2.93 to 2.99), `warningStrong` (2.89 to 2.95) and `dangerAccent` on Harvest (2.99). Fix: they are tested on `surface` (cards and chips, where they sit: 3.12, 3.08, 3.19); any use on the bare background found in T1 moves to the Strong shade (`infoStrong`, `dangerStrong`). success, warning and trendUp are below 3 in Pasture already (known, for K0).

## 6. One-off roles (fixed in every theme; never derived)

`chart1` #3D5A80, `chart2` #6A4C93, `chart3` #B56A00, `chart4` purple, `chart5` blueGrey, `chart6` teal, `chart7` indigo, `chart8` amber 700, `chart9` deep orange (F6: Reorder Soon, Debt Reminder); `chartService1-4` #5C7C99, #8FA998, #B98B6F, #9B8AA6; `roleOwner`/`Strong` indigo, `roleCoAdmin`/`Strong` teal, `roleAssistant`/`Strong` blueGrey, `rolePlatformAdmin` deep purple; `trendUp`/`trendDown`. Raw KEEPs: A18 (#E59A00 debt category), A19 is now `chart4`. The insights service palette also uses the brand primary and accent directly (section 8): there they should follow the theme.

## 7. Text roles on surface roles, every theme (4.5 text, 3.0 icons and large text)

| Text role | surface #FFFFFF | surfaceMuted #F5F5F5 | bg Pasture | bg Clinic | bg Harvest | bg Ledger |
|---|---|---|---|---|---|---|
| textStrong (black) | 21.00 | 19.26 | 20.59 | 19.87 | 19.66 | 20.07 |
| textPrimary (black87) | 15.91 | 14.77 | 15.62 | 15.23 | 15.09 | 15.38 |
| textSecondary (black54) | 4.61 | 4.54 | 4.59 | 4.56 | 4.56 | 4.54 |
| textSoft (grey 700) | 6.19 | 5.68 | 6.07 | 5.86 | 5.80 | 5.92 |
| textMuted (grey 600) | 4.61 | **4.23** | 4.52 | **4.36** | **4.31** | **4.40** |
| textHint (grey 500) | 2.68 | 2.46 | 2.63 | 2.54 | 2.51 | 2.56 |
| textDisabled (grey 400) | 1.88 | 1.72 | 1.84 | 1.78 | 1.76 | 1.80 |

| On brand fills | Pasture | Clinic | Harvest | Ledger |
|---|---|---|---|---|
| onPrimary on primary / sidebarHover / sidebarPress | 7.34 / 5.32 / 6.61 | 8.86 / 7.68 / 9.06 | 11.60 / 9.79 / 11.14 | 14.63 / 12.69 / 14.23 |
| onPrimaryMuted (white70) on primary / sidebarHover | 4.58 / **3.44** | 5.26 / 4.66 | 6.60 / 5.75 | 7.94 / 7.02 |
| onPrimarySubtle (white24) on primary | 1.80 | 1.86 | 2.08 | 2.17 |
| primary on surface / on quickActionTintPrimary | 7.34 / 6.27 | 8.86 / 7.54 | 11.60 / 9.59 | 14.63 / 12.29 |
| textPrimary on quickActionTintAccent | 14.31 | 14.15 | 14.21 | 12.79 |
| brandTeal on surface (login links) | **3.89** | **3.48** | 7.17 | 8.45 |
| brandTealGlow on primary (login glow text) | 4.99 | 5.69 | 5.63 | 8.28 |
| accent on background (accent as text: not allowed, D10) | 1.77 | 1.95 | 2.00 | 2.42 |

Fails and what to change:
- **textMuted on the new backgrounds (4.31 to 4.40) and on surfaceMuted (4.23, already today):** make `textMuted` neutral-per-theme: Pasture keeps grey 600 #757575; Clinic and Harvest #727272, Ledger #737373 (the lightest grey reaching 4.5 on that background; the difference cannot be seen). surfaceMuted stays a known fail in every theme (fills behind muted text are rare; K0 reviews it).
- **textHint, textDisabled, onPrimarySubtle:** fail in Pasture today and are not body text (hints, disabled, dividers on the sidebar). Tested at "no worse than Pasture minus 0.2", listed as known; not changed in T1.
- **onPrimaryMuted on sidebarHover, Pasture 3.44:** today's value; passes 3.0 (it is the secondary line under a hovered item). Known.
- **brandTeal as link text on the login card (Pasture 3.89, Clinic 3.48):** passes 3.0 only. Today's Pasture value; it may not change in T1. Recommend (owner, later): the links use `primary` (7.34 to 14.63). Clinic is the theme where this is weakest.
- `textSecondary` on surfaceMuted and Ledger background: 4.54, passes by 0.04: pinned by the test.

## 8. Danger red, and places that bypass the theme

Primary vs the danger reds (dE00; under 20 = hard to tell apart): Pasture 43.4 (closest: dangerDeep), Clinic 43.8, Harvest **24.7** (brown vs dangerDeep #B71C1C; passes, closest), Ledger 39.1. Harvest's derived roles after the warm guard: 18.7 (`brandTeal`, the login teal, not near an error) to 35.5. The accent is close to `warning` orange in Pasture (dE 9.2, today) and Harvest (9.8): fine, because D10 keeps the accent for interactive states and no state relies on colour alone.

Direct `AppPalette` uses T1 must resolve (13 outside `lib/theme`, plus `pdf_palette.dart`): `main.dart:93-95` (names a widget test checks: keep, they describe Pasture), `main.dart:760` `_deepGreen` on the no-facility screen (-> `context.colors.primary`), `insights_screen.dart:38,40` (-> `context.colors.primary/accent`), the receipt previews (`receipt_preview_screen.dart:574,584,661`, `service_receipt_preview_screen.dart:539,549,627`) and `pdf_palette.dart:30`: **stay Pasture** (receipts and PDFs are the business's printed brand and stay light, D11), `vetbiz_loading_indicator.dart:41` (shown before settings load: stays Pasture background).

## 9. Storing the theme, legacy ids, adding a theme

- **Storage unchanged:** key `ui_color_theme` in SharedPreferences via `UiSettingsProvider`, device-local.
- **AppColorTheme becomes:** `id`, `name` (English, technical), `primary`, `accent`, `background`; `available` is removed (all four selectable). `all = [pasture, clinic, harvest, ledger]`, `defaultId = 'pasture'`.
- **Legacy ids:** `static const legacyIds = {'kilimanjaro': 'pasture'}` in `AppColorTheme`; `byId` maps through it, and any unknown id (`serengeti`, `victoria`, which were never selectable so never saved, or anything else) returns `pasture`. When the read id was a legacy one, the provider writes `pasture` back once, so the old id does not linger.
- **Names:** shown through one lookup `colorThemeLabel(id)` in `lib/l10n` (like `facilityTypeLabel`), with ARB keys `uiSettings_themePasture/Clinic/Harvest/Ledger` (Kiswahili draft); the three old keys are retired. This reads D10's "kept in one place" together with the localisation rule (every shown text comes from the ARB). Owner: confirm.
- **Adding a theme later:** one entry in `AppColorTheme.all` (id, primary, accent, background) plus its ARB label. Every brand-linked role is derived by section 4's rules, and the tests loop over `AppColorTheme.all`, so the new theme is checked with no test edit.
- **`AppColors.fromTheme`** reads `theme.background` and derives the six roles (and `textMuted`, section 7) from the theme; `AppTheme.build` uses `theme.background` instead of the constant.

## 10. Test plan (T1)

1. **Pasture is unchanged:** every `AppColors` role for `pasture` equals today's value (the existing `tokens_test.dart` group and the R2 pins keep passing unchanged).
2. **Each theme builds a full AppColors:** for every theme in `AppColorTheme.all`, `fromTheme` gives every role, and `copyWith()`/`lerp(...,0)` keep them.
3. **The derived values:** the 6 x 4 table of section 4 pinned exactly; the warm guard (a red-hued primary keeps its hue, S <= 0.55) and the visibility floor (hover dE >= 8 from primary) each tested with a made-up theme.
4. **Contrast, computed in the test:** every pair of sections 2 and 7 at its threshold (4.5 text, 3.0 icons, large text and accent on primary) for every theme; the known Pasture fails listed with their reason and held at "no worse than Pasture minus 0.2"; primary vs every danger red dE >= 20.
5. **Legacy and storage:** `byId('kilimanjaro') == pasture`, `byId('serengeti')`, `byId('victoria')`, `byId(null)`, `byId('x')` all `pasture`; a saved `clinic` is restored after a provider restart (SharedPreferences mock); a saved `kilimanjaro` loads as `pasture` and is rewritten.
6. **UI:** the UI Settings dialog shows four selectable themes, no "Coming soon"; choosing one rebuilds the app; `flutter analyze` 0 issues, the guard at zero.

## 11. Rollout and rollback

T1 in small commits: (1) `AppColorTheme` with background and the four themes, legacy map, tests; (2) the derivation in `AppColors.fromTheme` with tests; (3) the dialog and labels (ARB, export tool); (4) the direct `AppPalette` uses of section 8. T1 is a HARD STOP: the owner views each theme on the 13 R0 screens. Rollback: revert T1's commits; a device that saved `clinic`, `harvest` or `ledger` falls back to `pasture` through `byId`, so nothing breaks. No server or rules change.

OWNER DECISION: PENDING
