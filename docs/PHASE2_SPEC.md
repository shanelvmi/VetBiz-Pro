# Phase 2 Spec: one home for every hardcoded value

**For:** Claude Code. **Owner:** Shanel.
**Written against:** commit `587387c`. Baselines at that commit:
- `flutter analyze`: 171 issues (0 errors, 19 warnings, 152 infos)
- `cd functions && npm test`: 81 passing
- rules tests: 60 passing
- app: 151 Dart files, about 72,000 lines

**Where this file lives:** `docs/PHASE2_SPEC.md`. Read `CLAUDE.md` first, then this file in full before editing anything.

---

## 0. Rules of engagement (read these twice)

1. **Work in the order of section 10.** One step at a time. Do not start the next step until the owner says so, unless the step says "continue".
2. **Every batch ends the same way:** run `flutter analyze` and `flutter test`; the error count stays 0, the warning count never rises above 19, nothing new appears. Run the guard test (section 9). Commit with a message that says what changed and why. Then write the report in section 11.
3. **No behaviour change.** No change to what is stored in Firestore. No change to a server function. Nothing is deployed.
4. **No visual change except the explicit snap tables in section 4.** A snap is a deliberate, listed exception. Anything else that would look different must stop and go in the report.
5. **List, do not silently improve.** If a place formats or behaves differently from the new shared helper, keep its exact output by using the matching helper method. Report any difference you would like to make. Do not make it.
6. **Never invent a design decision.** If a value has no home in this spec: keep the original value, give it a local named constant with a comment, and add one line to `docs/design-open-questions.md` (file, line, value, what it seems to be for). The owner decides later.
7. **Mechanical first, judgement second.** Write a throwaway script (put it in `tool/`, mark it as one-off) for replacements that are unambiguous. Do the ambiguous ones by hand, using the decision tables.
8. **Work in small batches.** About 300 changed lines or one folder, whichever is smaller. The big files (section 10) are split.
9. **Stop and ask** if analyze errors appear that you cannot fix within the batch, if more than five tests fail, or if a change would need the server or the rules to change.
10. **The owner keeps the permission mode on default or acceptEdits.** Do not ask to change it.

---

## 1. Goal

Every value that controls how the app looks, behaves or speaks lives in exactly one place, and screens only refer to it.

**Success means:**

1. Styling values come from tokens (`lib/theme/`).
2. Business numbers, formats, limits and contacts come from config (`lib/config/`).
3. Strings used as data (collection names, roles, statuses, payment method keys) come from constants (`lib/data/`).
4. User-facing text comes from language files (`lib/l10n/`).
5. Today's look is unchanged, apart from the snap tables.
6. A test makes it impossible to add a new raw value by accident (section 9).
7. **The proof:** changing one value in one file changes the whole app. For example, changing `AppPalette.primary` temporarily changes every brand surface. This is demonstrated at the end, then reverted.

**Not in this phase:** the other colour themes, Dark Mode, facility-level currency (needs a data-model change), changing screen designs, translating stored data.

---

## 2. Principles (decisions already made, do not reopen)

1. **Four homes.** Look → `lib/theme/`. Behaviour and rules → `lib/config/`. Data strings → `lib/data/`. Words → `lib/l10n/`.
2. **Dimensions are `static const`.** Spacing, radius, sizes, durations and so on stay usable inside `const` widgets. Only colours, and text styles that carry a colour, depend on the theme.
3. **Exact first.** Tokens reproduce today's values, so the migration changes nothing visible. Tidying the scales (merging near-duplicates) is a separate, visually reviewed step (2R) that is cheap afterwards, because each value then lives in one place.
4. **Naming.**
   - Colours get **semantic names** (`textMuted`, `danger`), because Dark Mode and colour themes need meaning, not shade.
   - Dimension ladders get **numeric names that mirror the value** (`AppSpacing.s12`, `AppRadius.r10`, `AppFontSize.f12_5`), so the mechanical migration is lossless and unambiguous.
   - **Role styles** (`AppText.body`) are provided for new code, so new screens do not add to the ladder.
5. **Stored value is not the displayed label.** `'Cash'` is a key in saved data. It never changes; its on-screen label is translated.
6. **Anything shared with the server is test-linked.** If the app and the server both know a constant (invite code length, role and status names), a test compares them.
7. **Values the platform admin must change without a release** (plan prices, trial length) stay in Firestore `platform_config/settings`. The app never hardcodes them.

---

## 3. Target structure

```
lib/theme/
  app_palette.dart       (exists) the raw brand colours; the one place a hex lives for the brand
  app_colors.dart        ThemeExtension<AppColors>: semantic colour roles (section 4.1)
  app_theme.dart         AppTheme.build(AppColorTheme, Brightness) -> ThemeData (moves main.dart's ThemeData here, unchanged)
  app_text.dart          AppFontSize, AppFontWeight, AppText (role styles)
  app_dimens.dart        AppSpacing, AppRadius, AppIconSize, AppElevation, AppAlpha, AppSizes
  app_motion.dart        AppMotion (animation durations)
  app_breakpoints.dart   AppBreakpoints + BuildContext helpers
  theme_context.dart     extension: context.colors, context.screenWidth, context.isCompact ...
  pdf_palette.dart       colours for PDF/printing (not theme-dependent)
lib/config/
  app_info.dart          AppInfo (name)
  app_defaults.dart      AppDefaults (currency, country code, locale, timezone)
  money.dart             Money.format / Money.plain
  app_limits.dart        page sizes, query caps
  app_timeouts.dart      network and UI timeouts
  app_ranges.dart        day/week/month/year and default date ranges
  app_rules.dart         invite code length, attention days, other business numbers
  payment_methods.dart   PaymentMethod (stable key + label lookup)
  app_date_format.dart   named date and time formats
  app_links.dart         WhatsApp links, support contact
  restock_rules.dart     the restock-days table now inside usage_calculator_service
lib/data/
  collections.dart       Collections (all Firestore collection names)
  user_role.dart         UserRole (admin, assistant, ...)
  user_status.dart       UserStatus (pending, active, deactivated, rejected)
  subscription_keys.dart stored subscription status keys
lib/l10n/
  app_en.arb, app_sw.arb (+ generated AppLocalizations)
tool/
  check_hardcoded.dart       counts raw values per rule per file; updates the baseline downwards only
  hardcoded_baseline.json    the ratchet
test/
  hardcoded_values_test.dart fails if any count rises above the baseline
  tokens_test.dart           default theme values equal the legacy values (section 4)
  money_test.dart, date_format_test.dart
docs/
  design-open-questions.md
```

Allowed to contain raw values (excluded from the guard): `lib/theme/**`, `lib/config/**`, `lib/data/**`, `lib/l10n/**`, generated files, `tool/**`.

---

## 4. Token tables (exact)

All "uses" are counts at commit `587387c`. A token that exists today is **kept exactly**. A value not in the table is a **snap** to the listed token.

### 4.1 Colours: `AppColors` (ThemeExtension)

Every role's default value (the Kilimanjaro Green light theme) is **exactly** the legacy value. Roles are defined in `AppColors.fromTheme(AppColorTheme)`. For now only the brand roles vary by theme; neutrals and statuses are shared.

| Role | Default value | Replaces (uses) |
|---|---|---|
| `primary` | `AppPalette.primary` | brand green |
| `accent` | `AppPalette.accent` | brand amber |
| `background` | `AppPalette.background` | page background |
| `surface` | `Colors.white` | `Colors.white` as a fill: card, sheet, dialog, app bar, input (most of 468) |
| `surfaceMuted` | `Colors.grey.shade100` | grey[100] (10) |
| `onPrimary` | `Colors.white` | `Colors.white` as text/icon on a coloured fill |
| `onPrimaryMuted` | `Colors.white70` | white70 (6) |
| `onPrimarySubtle` | `Colors.white24` | white24 (5) |
| `textStrong` | `Colors.black` | black (42) |
| `textPrimary` | `Colors.black87` | black87 (117); grey[800] (5) |
| `textSecondary` | `Colors.black54` | black54 (46) |
| `textSoft` | `Colors.grey.shade700` | grey[700] (69 + 6) |
| `textMuted` | `Colors.grey.shade600` | grey[600] (300 + 23) |
| `textHint` | `Colors.grey` (= shade500) | `Colors.grey` (238), grey[500] (76 + 10) |
| `textDisabled` | `Colors.grey.shade400` | grey[400] as text or icon (46 + 18) |
| `borderStrong` | `Colors.grey.shade400` | grey[400] as a border |
| `border` | `Colors.grey.shade300` | grey[300] (8 + 18); grey[350] (3) |
| `divider` | `Colors.grey.shade200` | grey[200] (12) |
| `success` | `Colors.green` | green (142); green[600] (4) |
| `successStrong` | `Colors.green.shade700` | green[700] (21) |
| `danger` | `Colors.red` | red (135) |
| `dangerAccent` | `Colors.redAccent` | redAccent (141) |
| `dangerSoft` | `Colors.red.shade400` | red[400] (18) |
| `dangerStrong` | `Colors.red.shade700` | red[700] (14) |
| `dangerDeep` | `Colors.red.shade900` | red shade900 (5) |
| `warning` | `Colors.orange` | orange (64); amber[700] (4) |
| `warningStrong` | `Colors.orange.shade800` | orange[800] (12 + 5) |
| `info` | `Colors.blue` | blue (31) |
| `infoStrong` | `Colors.blue.shade700` | blue[700] (8) |

Notes:
- The two reds (`danger`, `dangerAccent`) are intentionally kept apart: both are used about 140 times today and they are visibly different shades. Merging them is a 2R decision.
- `Colors.teal` (8), `purple` (7), `deepPurple` (6), `blueGrey[400]` (3): work out what each is for. If a chart or category colour, create `chart1..chartN` roles holding the exact legacy values. Otherwise create a role named for its purpose. Never snap these to another role.
- About 33 distinct raw hex values (about 60 uses, for example `#3E8E82`, `#E2E8E6`, `#7EE8CB`, `#B3261E`, `#E0A32E`, `#3D5A80`) and about 30 inline copies of the brand hex: brand hexes become `AppPalette`/role references. Others: if a role's value is within 12 on every RGB channel, use that role. If not, add a new named role with the exact value, named for its purpose.
- `Colors.transparent` is allowed everywhere. Do not tokenise it.
- Opacity on a colour is done with `AppAlpha` (4.7): `context.colors.primary.withValues(alpha: AppAlpha.a10)`.

`tokens_test.dart` must assert every role's default value equals the legacy value above. That test is the proof of "no visual change" for colours.

### 4.2 Typography

**Font sizes: `AppFontSize`** (keep exact):

`f9, f10, f10_5, f11, f11_5, f12, f12_5, f13, f13_5, f14, f14_5, f15, f16, f17, f18, f19, f20, f22, f24, f28` (24 and 28 are rare but kept exact: they are display sizes).

Snaps (all ≤ 1px; ties go **up**, for legibility):

| Found | Uses | Becomes |
|---|---|---|
| 8 | 3 | f9 |
| 8.5 | 4 | f9 |
| 9.5 | 5 | f10 |
| 15.5 | 2 | f16 |
| 16.5 | 1 | f17 |

98.8% of today's uses are unchanged (15 of 1,259 move). (12.5 is the second most-used size, 195 uses; it is **not** snapped.)

**Weights: `AppFontWeight`:** `regular` (normal), `medium` (w500), `semibold` (w600), `bold` (`FontWeight.bold`; w700 maps here), `extraBold` (w800, 3 uses, kept).

**Role styles: `AppText`** (for new code; they read colours from the theme):
`caption` (f11), `bodySm` (f12_5), `body` (f13), `bodyLg` (f14), `label` (f12_5 semibold), `title` (f16 bold), `headline` (f20 bold), `display` (f28 bold). Migration does **not** use these. It uses the ladder, so nothing shifts.

**Rules:**
- Replace the number only: `fontSize: 12.5` → `fontSize: AppFontSize.f12_5`. Keep the rest of the `TextStyle`.
- `Theme.of(context).textTheme` is not used by the app today (0 uses). Do not start wiring it in this phase.

### 4.3 Spacing: `AppSpacing`

Applies to `EdgeInsets.*` (`all`, `symmetric`, `only`, `fromLTRB`), `SizedBox(height/width)` for values **≤ 32**, and `Padding`/gap values.

Tokens (exact): `s2, s3, s4, s6, s8, s10, s12, s14, s16, s18, s20, s22, s24, s28, s32`.

| Found | Uses | Becomes |
|---|---|---|
| 1 | 3 | s2 |
| 1.5 | 4 | s2 |
| 5 | 2 | s4 |
| 7 | 7 | s6 |

99% unchanged. `0` stays `0` (use `EdgeInsets.zero`). A `SizedBox` width or height **above 32** is a size, not spacing: use `AppSizes` (4.10) or a named local constant with a comment.

### 4.4 Radius: `AppRadius`

Tokens: `r4, r6, r7, r8, r10, r12, r14, r16, r20, r24`, plus `pill = 999`.

| Found | Uses | Becomes |
|---|---|---|
| 2, 3 | 3 | r4 |
| 9 | 2 | r8 |
| 11 | 4 | r10 |
| 18 | 3 | r16 |
| 19 | 1 | r20 |
| 28, 30 | 2 | if the box is a circle (width == height == 2 × radius) → `pill`; otherwise r24 |

Replace the number inside `BorderRadius.circular(...)` and `Radius.circular(...)`.

### 4.5 Icon sizes: `AppIconSize`

Tokens: `i12, i14, i16, i18, i20, i22, i32, i56, i64`.
Snaps: 15 → i16, 17 → i18, 19 → i20 (35 uses, ≤ 1px).
Applies only to `Icon(size:)` and `iconSize:`. Do not touch other `size:` parameters.

### 4.6 Elevation: `AppElevation`

Tokens: `e0, e1, e2, e6, e8`. Snaps: 3 → e2, 4 → e2.

### 4.7 Opacity: `AppAlpha`

Tokens: `a05 (0.05), a10 (0.1), a15 (0.15), a20 (0.2), a30 (0.3), a40 (0.4), a50 (0.5), a70 (0.7)`.

| Found | Becomes |
|---|---|
| 0.04, 0.06 | a05 |
| 0.08, 0.12 | a10 |
| 0.25 | a30 |
| 0.35 | a40 |

Maximum shift 0.05 on a tint. `withOpacity` is not used; `withValues(alpha:)` is.

### 4.8 Motion: `AppMotion`

For animation durations only (not timeouts, not business durations):

| Token | Value | Replaces |
|---|---|---|
| `fast` | 150 ms | 150, 180 |
| `normal` | 220 ms | 220, 250 |
| `slow` | 300 ms | 300 |
| `slower` | 400 ms | 380, 400 |
| `slowest` | 500 ms | 500 |
| `loop` | 900 ms | repeating pulses and shimmers (900; 700 only if it is a loop) |

Classify every `Duration(` by purpose first (animation, timeout, delay, toast, business range). Anything that is a snackbar or toast duration is `AppMotion.toastShort` (2 s) or `toastLong` (3 s).

### 4.9 Breakpoints: `AppBreakpoints`

Breakpoints change **where a layout flips**, so they are never snapped in this phase.

- Tiers: `compact = 600`, `medium = 900`, `expanded = 1024` (the sidebar threshold).
- Every other distinct value found (700 ×17, 860 ×6, 820, 720, 760, 480, 1100, 640, 420, 560, 800) keeps its **exact** number, as a constant named for the layout decision it controls (for example `salesFormTwoColumn = 700`), with a doc comment listing `file:line`. Aim for at most about 12 constants.
- `theme_context.dart` gives `context.screenWidth`, `context.isCompact` (< 600), `context.isMedium` (600 to < 900), `context.isExpanded` (≥ 1024).
- Harmonising them is step 2R, and needs screenshots at the boundary widths.

### 4.10 Sizes: `AppSizes`

Dialog and content max widths, as tokens, snapped within 40 px:

| Token | Value | Replaces |
|---|---|---|
| `dialogXs` | 340 | 340, 360 |
| `dialogSm` | 420 | 400, 420, 440, 460 |
| `dialogMd` | 500 | 480, 500, 512 |
| `dialogLg` | 560 | 560 |
| `formMax` | 700 | 700 (16 uses) |
| `contentSm` | 820 | 800, 820 |
| `contentMd` | 900 | 900 |
| `contentLg` | 1000 | 1000 |
| `contentXl` | 1080 | 1080 |
| `pageMax` | 1440 | 1440 |

Also here: the dashboard sidebar widths (expanded and collapsed) and standard avatar sizes, once you find them. Tiny constraints (for example `maxWidth: 110`) are not page widths: name them locally.

---

## 5. Colour migration: decision rules

**Unambiguous (script them):** `Colors.black87`, `black54`, `black`, `grey[600]`/`shade600`, `grey[700]`, `grey[300]`, `grey[200]`, `grey[100]`, `green`, `green[700]`, `red`, `redAccent`, `red[400]`, `red[700]`, `orange`, `orange[800]`, `blue`, `blue[700]`, `white70`, `white24` → the role in 4.1.

**Ambiguous (decide by the property the colour is used in):**

| Legacy | Used as | Role |
|---|---|---|
| `Colors.white` | fill: `Container.decoration.color`, `Card.color`, `backgroundColor`, `fillColor` | `surface` |
| `Colors.white` | `TextStyle.color`, `Icon.color`, `foregroundColor`, on a coloured fill | `onPrimary` |
| `Colors.grey` / `grey[500]` | `TextStyle.color` or hint | `textHint` |
| `Colors.grey` / `grey[500]` | `Icon.color` | `textHint` |
| `Colors.grey[400]` | `Border`, `BorderSide`, `Divider` | `borderStrong` |
| `Colors.grey[400]` | text or icon, disabled | `textDisabled` |

**No `BuildContext`?** Colours that live in `static const` fields, models, services or helper functions:
- In a widget's `build` tree: use `context.colors`.
- In a helper: pass `AppColors colors` as a parameter.
- Where a `const` is required: the colour is theme-dependent, so the widget stops being `const`. That is expected, and the reason for small batches.
- **PDF and printing code is not themed.** Use `pdf_palette.dart` (exact legacy values, built from `AppPalette`).

**Do not** introduce `Theme.of(context).colorScheme` in this phase.

---

## 6. Config (`lib/config/`)

| File | Contents | Today it is… |
|---|---|---|
| `app_info.dart` | `AppInfo.name = 'VetBiz Pro'`, `shortName` | "VetBiz" typed in 57 strings in 18 files |
| `app_defaults.dart` | `currencyCode = 'TZS'`, `currencySymbol = 'Tsh'`, `countryCallingCode = '255'`, `timezone = 'Africa/Dar_es_Salaam'`, default locale `en`, supported locales `en`, `sw` | `settings_provider` (a currency list that nothing reads; see section 8 for the language list, which IS used), `client_duplicate_matcher`, `register_screen` |
| `money.dart` | `Money.format(num)` → `Tsh 12,500`; `Money.plain(num)` → `12,500`. Same output as today: locale `en_US`, 0 decimals, symbol `Tsh ` | `NumberFormat.currency` ×11 (8 private `_moneyFormat` copies), `decimalPattern` ×16, "Tsh/TSh/TZS" text in 170 places in 40 files |
| `app_limits.dart` | `pageSize = 25` (14 files), `ledgerQueryCap = 500`, `recentActivityCount = 5`, and the other `.limit(n)` values: 1, 2, 50, 40, 20, 8, each named for its purpose | `.limit(n)` ×21 |
| `app_timeouts.dart` | Every `timeout(` and delay, named by purpose. Likely: profile load 10 s, facility load 15 s, sign-out 10 s, login safety net 6 s, skeleton fallback 8 s, auth poll 2 s, uploads. **Confirm each value and purpose in the code; do not trust this list.** | `Duration(seconds:)` |
| `app_ranges.dart` | `day`, `week` (7), `month` (30), `year` (365), and named defaults (default sales range = 30 days, archive step, and so on) | `Duration(days: n)` ×41 |
| `app_rules.dart` | `inviteCodeLength = 6`, `subscriptionAttentionDays = 7`, and any other business number found | `main.dart:1068`, `subscription_provider.dart` |
| `payment_methods.dart` | `PaymentMethod` with a **stable key** (`'Cash'` …, never changed) and a label lookup (translated later) | `'Cash'` etc. typed in 8 files (30 uses); they are also **saved as map keys** |
| `app_date_format.dart` | Named formats, **exact patterns kept** (see below) | `DateFormat('…')` with 22 patterns |
| `app_links.dart` | `AppLinks.whatsApp(phone, {text})`, `AppContact.supportPhone = '+255719199916'` | 3 `wa.me` builders; `settings_screen.dart:656` |
| `restock_rules.dart` | the table `_RestockDayCounts` for 'Weekly', 'Every 2 Weeks', 'Monthly' | inside `usage_calculator_service.dart:72` |

**Date formats (exact patterns, kept):**
`date` = `dd MMM yyyy` (48+), `dateNoPad` = `d MMM yyyy`, `dateShort` = `d MMM`, `dateDay` = `dd MMM`, `dateLong` = `EEEE, d MMM yyyy`, `dateLongFull` = `EEEE, d MMMM yyyy`, `monthYear` = `MMMM yyyy`, `monthYearShort` = `MMM yyyy`, `time24` = `HH:mm`, `time12` = `hh:mm a`, `time12Short` = `h:mm a`, `dateTime24Seconds` = `dd MMM yyyy - HH:mm:ss`.
`yyyy-MM-dd` (10 uses) is a **data key** (daily summary ids and queries). It goes in `lib/data/` as `DataKeys.isoDay` and is never localised.

**Rules:**
- Money in text that is **saved** (activity and transaction descriptions in `transaction_provider.dart`, `service_provider.dart`) goes through `Money` too. If the current output differs (for example no thousands separator), keep the exact current output and report it (rule 5).
- `AppContact.supportPhone`: keep as a constant now. Making it editable by the platform admin (a field on `platform_config/settings` with this as the fallback) is optional step 2H.
- Do not add a VAT or tax setting. There is none today.

**Shared with the server (add a test):**
- `AppRules.inviteCodeLength` and the invite alphabet must equal `INVITE_CODE_LENGTH` (`membership.js:30`, value 6) and `INVITE_ALPHABET` (`membership.js:28`) in `functions/membership.js`. Extend `functions/test/endpoints.test.js` to compare them. It already does this for the region: it reads the Dart file as text and extracts the value with a regex (`kMembershipFunctionsRegion`), so do the same for the new Dart constants.
- `INVITE_ALPHABET` is already exported in `helpers`; **`INVITE_CODE_LENGTH` is not.** Add it to the exported `helpers` object (`membership.js:828`). This one-line export, which changes no behaviour, is the **only** server-file change allowed in this phase. Mention it in the report, and run `npm test` afterwards (81 must still pass).
- `UserRole` and `UserStatus` values must match the values the server writes. Same approach.

---

## 7. Data constants (`lib/data/`)

| What | Today | Home |
|---|---|---|
| Collection names | 479 uses, 35 names, 69 files (`facilities` ×198, `users` ×45, `products` ×27, …) | `Collections.facilities`, … (subcollection names too) |
| Roles | `'admin'` ×40, `'assistant'` ×33, `'owner'` ×3 | `UserRole` with `.key`, `fromKey()` (unknown → a safe default, never a crash) |
| Statuses | `'active'` ×51, `'pending'` ×34, `'deactivated'` ×25, `'rejected'` ×15 | `UserStatus` |
| Subscription keys | trial, grace, locked, expired | `lib/data/subscription_keys.dart` (stored values; the existing `SubscriptionStatus` enum keeps working) |
| A few field names | `'facilityId'` ×72, `'status'` ×30, `'role'` ×22, `'userId'` ×21, `'createdAt'`, `'updatedAt'` | `Fields.facilityId`, … (only these; do not chase every field) |

**Rules:** the stored string never changes. Use `.key` where the code writes or compares. Replace only literals that already exist. Do not rename anything in Firestore.

---

## 8. Localisation (`lib/l10n/`)

Language setting exists today (English and Kiswahili) but nothing translates. There are 1,683 user-facing strings (about 1,382 `Text('…')` and 192 snackbars among them).

**Setup (Flutter's own tooling):**
- Add `flutter_localizations` (sdk) and `generate: true` under `flutter:` in `pubspec.yaml`. `intl` is already present.
- `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`.
- `MaterialApp`: `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: AppLocalizations.supportedLocales`, `locale:` from `UiSettingsProvider`.
- Add `locale` to `UiSettingsProvider` (device-local, saved like `layoutFixed`).
- **Careful: the language list is used.** `settings_screen.dart` has a real Language picker (lines about 53, 270 and 514 to 528) that reads `supportedLanguages` and `selectedLanguage` and calls `setLanguage` on `SettingsProvider`. Today it only changes an in-memory value that nothing reads, and it is not saved. Rewire **that existing picker** to the new persisted `UiSettingsProvider.locale`, then remove `selectedLanguage`, `supportedLanguages` and `setLanguage` from `SettingsProvider`. Keep one language picker, not two. Do not add a second Language row to the UI Settings dialog unless the owner asks.
- **Currency:** nothing reads `selectedCurrency` or `supportedCurrencies`, and the Currency tile in Settings does nothing. Remove the dead currency state from `SettingsProvider` and leave the tile as it is. A real currency choice needs a facility-level field (step 2H).
- Helper: `context.l10n` (extension) → `AppLocalizations.of(context)`.

**Rules:**
- English first, complete. Kiswahili is drafted by you and **marked for native-speaker review**, clearly, in the ARB `@@` description of each draft key and in the report. Do not present it as final.
- Key names: `<area>_<element>`, for example `sales_saveButton`, `team_rejectConfirmTitle`. Strings used in many places (Save, Cancel, Delete, Search…) go under `common_`.
- Use ICU placeholders and plurals (`{count, plural, …}`), never string concatenation, for text with values.
- **Never translate stored data:** payment method keys, role and status keys, and any text saved to Firestore (activity descriptions, transaction descriptions). Saved descriptions stay in one fixed language (English) and are not UI strings. Making them structured (type + parameters, translated at display) is a future change.
- Server error messages shown in the app are English from the server. Leave them, and list them in the report as a future item.
- `AppInfo.name` is passed as a placeholder (`{appName}`), not typed.

---

## 9. The guard (a ratchet: counts may go down, never up)

`tool/check_hardcoded.dart` scans `lib/` (excluding the allowed folders) and counts matches per rule per file. `tool/hardcoded_baseline.json` holds the allowed count per rule per file. `test/hardcoded_values_test.dart` fails if any count is above its baseline. A new file has a baseline of 0. `dart run tool/check_hardcoded.dart --update` rewrites the baseline, and **refuses to raise any number**.

| Rule | Pattern (sketch) |
|---|---|
| R1 raw colour | `Color\(0x`, `Colors\.(?!transparent)` |
| R2 raw font size | `fontSize:\s*\d` |
| R3 raw radius | `Radius\.circular\(\s*\d` |
| R4 raw spacing | `EdgeInsets\.(all\|symmetric\|only\|fromLTRB)\(` with a non-zero number; `SizedBox\((height\|width):\s*\d` |
| R5 raw duration | `Duration\(` |
| R6 raw query limit | `\.limit\(\s*\d` |
| R7 raw breakpoint | `(width\|maxWidth)\s*(>=\|<=\|>\|<)\s*\d{3}` |
| R8 raw currency text | `'T(sh\|Sh\|ZS)` and `"T(sh\|Sh\|ZS)` |
| R9 raw collection name | `\.collection\('` |
| R10 raw user-facing string | `Text\(\s*(const\s+)?['"]`, `SnackBar`, `labelText:\s*['"]`, `hintText:\s*['"]` (switched on in step 2F) |

- Create the baseline in step 2A with **today's counts** (a number per rule per file).
- Keep the scanner simple and readable. False positives that cannot be fixed go on a short, commented allowlist in the JSON.
- Mention the guard in `CLAUDE.md` ("do not add raw values; run `flutter test`").

---

## 10. Work plan

Each step has entry and exit criteria. **Stop after each step for the owner's go-ahead.** Steps are 2A, 2B, 2C, 2D, 2E, 2F (localisation), 2G (close-out), 2H (optional extras) and 2R (refinement).

### Step 2A: Foundation (no screen is touched)
- Create everything in section 3 that is code, with the values in sections 4 and 6.
- `AppTheme.build` replaces the `ThemeData` in `main.dart`. The result must be **identical** (move the code, do not rewrite it). `VetBizProApp` watches `UiSettingsProvider` and rebuilds the theme on change.
- `AppColors` registered as an extension on the theme. `AppColors.fromTheme(AppColorTheme)` returns the legacy values.
- Tests: `tokens_test.dart` (every role equals its legacy value), `money_test.dart` (exact legacy output), `date_format_test.dart`, the guard test and its baseline.
- Create `docs/design-open-questions.md`.
- **Exit:** analyze ≤ baseline; all tests pass; the app runs and looks identical; guard passes.

### Step 2B: Data constants
- Section 7, mechanically, folder by folder (about 479 + 170 literals).
- Add the app/server link tests (section 6, last block).
- **Exit:** analyze ≤ baseline; `npm test` still 81; guard R9 counts fall to 0 outside `lib/data/`; no behaviour change.

### Step 2C: Config
- Section 6, **by concern, not by folder** (money first, then limits, timeouts, ranges, rules, payment methods, date formats, links, restock, app info). The same file may be touched more than once; keep each commit to one concern.
- **Exit:** analyze ≤ baseline; guard R5, R6, R8 fall as far as the section 6 classification allows; no output differs (rule 5).

### Step 2D: Screens (all value categories, one pass per batch)
Apply sections 4 and 5 to each batch **once** (colours, type, spacing, radius, icons, elevation, alpha, motion, breakpoints, sizes together), so each file is opened once. Order: small to large. Hits counted at `587387c`:

| Batch | Contents | Hits |
|---|---|---|
| D1 | `lib/widgets/**`, `lib/utils/**` | small |
| D2 | `screens/payments`, `screens/subscription`, `screens/store` | ~520 |
| D3 | `screens/transactions`, `screens/debtors`, `screens/clients` | ~710 |
| D4 | `screens/admin`, `screens/settings` | ~520 |
| D5 | `screens/reports`, `screens/services` | ~1,100 (split into two) |
| D6 | `screens/products`, `screens/sales` | ~1,160 (split into two) |
| D7 | `screens/platform_admin` | 749 (split into two) |
| D8 | `screens/*.dart` at the top level: `login_screen`, `register_screen` (245 hits, 2 passes), the rest | ~430 |
| D9 | `screens/dashboard` (`dashboard_screen.dart` 325 hits: 3 passes by line range) | ~585 |
| D10 | `screens/facilities` (`facility_screen.dart` 360 hits: 3 passes by line range) | ~464 |

After each batch: the smoke checklist (section 12) for the screens in that batch.

### Step 2E: Consolidation check
- Run the guard. Remaining counts for R1 to R9 are listed and cleared, or each is justified in `docs/design-open-questions.md`.
- **Exit:** R1 to R9 are zero outside the allowed folders, or on the allowlist with a reason.

### Step 2F: Localisation
- Section 8. Order: setup + `common_` strings + the UI Settings language row, then by folder in the order of 2D. About 1,683 strings; batches of one folder.
- Switch on rule R10 once the first folder is done, with its own baseline, and let it fall.
- Can be delivered as a separate follow-up from 2E if the owner prefers.

### Step 2G: Close-out
- Update `CLAUDE.md`: replace the "Colours and design" section with the real rules (where tokens live, the guard, how to add a value).
- Do the proof from section 1.7: change `AppPalette.primary` to a different colour locally, run the app, confirm the whole brand surface changes, **revert**.
- Final report: the before/after table of the audit in Appendix A.

### Step 2H: Optional extras (only on request)
- Support contact editable from `platform_config/settings`, with the constant as fallback.
- Facility-level currency (needs a facility field and a data-model decision).

### Step 2R: Refinement (separate, visually reviewed, owner-approved)
Consolidate the ladders into role scales (for example 12.5 and 13 into one body size, the two reds into one danger), harmonise the breakpoints, and give the roles final values. Done by editing token values in one place, with before/after screenshots. Not part of "done" for this phase.

---

## 11. Report after every batch (copy this shape)

```
Step / batch:
Commit:
Files changed:
Replaced, by rule:   R1 colours n | R2 font n | R3 radius n | R4 spacing n | R5 duration n | R6 limit n | R7 breakpoint n | R8 currency n | R9 collection n
Snaps applied:       (each snap from section 4, with its count)
Not replaced:        (value, file:line, why, and the line added to design-open-questions.md)
Output differences:  (any place whose output would differ, kept as is, with a proposal)
flutter analyze:     before N (E/W/I)  ->  after N (E/W/I)
flutter test:        passed / failed
Guard:               before -> after, per rule
Anything surprising:
```

---

## 12. Smoke checklist (manual, per batch)

Run `flutter run -d chrome`. Open DevTools and watch the console for **`overflowed`** messages: there must be none. Check:

- As **admin:** Dashboard (sidebar expand and collapse, UI Settings → Layout Fixed on and off), Sales (add a sale, receipt preview), Products (add one with a photo), Team Members, Activity Log, Reports, Settings.
- As **assistant:** Dashboard, Activity Log (blue note), add a sale.
- Both a **wide** window (about 1400 px) and a **narrow** one (about 400 px), and one width near each breakpoint touched by the batch.

---

## 13. Risks and how they are handled

| Risk | Handling |
|---|---|
| Removing `const` (154 lines already use a brand colour inside a `const` widget) causes cascading compile errors | Small batches; analyze after each; the colour makes a widget non-const only where it is theme-dependent |
| Colours needed where there is no `BuildContext` | Section 5: pass `AppColors`, or `pdf_palette.dart` for printing |
| Text overflows after a snap | Snaps are ≤ 1px and listed; DevTools overflow check per batch |
| Breakpoint changes flip a layout | Never snapped in this phase |
| Translating stored data corrupts history | Section 8: stored values and keys are never translated |
| Giant files (facility 2,950 lines, dashboard 3,440, register 2,171) | Split by line range; commit per pass |
| A helper formats money differently from a screen | Rule 5: keep the exact output, report |
| Drift between app and server constants | Test-linked (section 6) |
| Scope creep | Rule 6 and `design-open-questions.md` |

---

## 14. Definition of done

- Guard rules R1 to R9 are zero outside the allowed folders (or allowlisted with a reason); R10 is zero or allowlisted for technical strings.
- `flutter analyze`: 0 errors, no more than 19 warnings, nothing new.
- `flutter test`, `npm test` (81 or more) and the rules tests (60) pass.
- Smoke checklist passed for every batch.
- The proof in 2G is done and reverted.
- `CLAUDE.md` updated. `docs/design-open-questions.md` is complete, for the owner's review.
- No change to Firestore data, rules or server behaviour.

---

## Appendix A: audit at commit `587387c`

| Measure | Count |
|---|---|
| Dart files / lines in `lib/` | 151 / 72,071 |
| Style-value hits (colour, type, radius, spacing, duration, limit, currency text) | 6,798 |
| User-facing strings | 1,683 |
| `TextStyle(` constructed by hand / theme text styles used | 1,446 / 0 |
| Distinct font sizes | 25 (20 kept exact, 5 snapped, 15 of 1,259 uses move) |
| Distinct radii | 18 |
| Distinct breakpoints | 15 |
| Distinct animation and timeout `Duration` values | 47 |
| Colours: `Colors.white` / grey family / red / green / orange | 468 / ~750 / ~320 / ~170 / ~85 |
| Distinct raw hex colours beyond the brand three | 33 (about 60 uses) |
| Currency text | 170 in 40 files |
| Collection names typed | 479 in 69 files |
| `.limit(n)` / page size 25 | 21 / 14 files |

## Appendix B: sketches (reference only; adapt and verify with `flutter analyze`)

```dart
// lib/theme/app_colors.dart
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.primary, required this.accent, required this.background,
    required this.surface, required this.textPrimary, required this.textMuted,
    // ... every role in 4.1
  });
  final Color primary, accent, background, surface, textPrimary, textMuted; // ...

  static AppColors fromTheme(AppColorTheme t) => AppColors(
        primary: t.primary, accent: t.accent, background: AppPalette.background,
        surface: Colors.white, textPrimary: Colors.black87, textMuted: Colors.grey.shade600,
        // ... exact legacy values from 4.1
      );

  @override
  AppColors copyWith({Color? primary /* ... */}) => AppColors(primary: primary ?? this.primary /* ... */);

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(primary: Color.lerp(primary, other.primary, t)! /* ... every field */);
  }
}

// lib/theme/theme_context.dart
extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  double get screenWidth => MediaQuery.of(this).size.width;
  bool get isCompact => screenWidth < AppBreakpoints.compact;
}

// lib/config/money.dart
class Money {
  Money._();
  static final NumberFormat _currency = NumberFormat.currency(
      locale: 'en_US', symbol: '${AppDefaults.currencySymbol} ', decimalDigits: 0);
  static final NumberFormat _plain = NumberFormat('#,##0', 'en_US');
  static String format(num amount) => _currency.format(amount); // Tsh 12,500
  static String plain(num amount) => _plain.format(amount);     // 12,500
}
```

Usage after migration:

```dart
Text('Total', style: TextStyle(
  fontSize: AppFontSize.f12_5,
  fontWeight: AppFontWeight.semibold,
  color: context.colors.textMuted,
));
Container(
  padding: const EdgeInsets.all(AppSpacing.s16),
  decoration: BoxDecoration(
    color: context.colors.surface,
    borderRadius: BorderRadius.circular(AppRadius.r12),
  ),
);
```
