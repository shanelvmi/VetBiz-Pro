# Phase 2, Step 2F: localisation (English and Kiswahili)

**For:** Claude Code. **Owner:** Shanel. **Part of:** `docs/PHASE2_SPEC.md` section 8 (this expands it; every rule in section 0 of that file still applies).
**Written against:** the state after the quality pass (analyze 38 to 41 infos, 0 errors, 0 warnings; 163 Flutter tests; 92 server tests).

---

## 1. Goal

Every piece of text a person reads in the app comes from language files, in English and Kiswahili, and the owner can switch between them in Settings. The words are reviewed by a native speaker (the owner) before they are called final.

**Not in this step:** dates and numbers (they keep their fixed formats), receipts and PDFs (their language is a facility business setting, a later feature), server messages, legal documents, the platform-admin console.

## 2. Decisions (made, do not reopen)

1. **Flutter's own system:** ARB files and the generated `AppLocalizations`. English is the template (`app_en.arb`); Kiswahili is `app_sw.arb`.
2. **Language is a saved device setting.** `UiSettingsProvider` gets `locale` (saved like `layoutFixed`). The existing Language picker in `settings_screen.dart` (it uses `supportedLanguages`, `selectedLanguage` and `setLanguage` on `SettingsProvider`, and does nothing today) is rewired to it. Keep **one** picker. Remove the dead language state from `SettingsProvider` afterwards. Default is English.
3. **Shared words are shared.** Words used in many places (Save, Cancel, Delete, Search, Yes, No, Close, Retry…) are `common_` keys. Expect roughly 1,000 unique keys from the 1,651 strings.
4. **Dates and numbers do not change.** `AppDateFormat` and `Money` keep their patterns and the `en_US` number format. Do not set `Intl.defaultLocale`.
5. **Stored data is never translated.** Activity descriptions, payment method keys, role and status keys, product categories as stored, and anything else written to Firestore keep their stored English values. Only the **display** of a stored key is localised, by a lookup (section 6).
6. **Context-free access exists.** `FriendlyError` and `AppFeedback` calls often happen after an `await`, with no `BuildContext`. Provide `L10n.current` (a static getter returning the `AppLocalizations` for the current locale, built with the generated `lookupAppLocalizations`). Widgets use `context.l10n`. Non-widget code uses `L10n.current`. `UiSettingsProvider` keeps `L10n.current` in step when the locale changes.
7. **Kiswahili is drafted by you and reviewed by the owner.** Nothing is "final" until the owner approves it (section 8).
8. **Out of scope, kept English with a reason on the guard allowlist:**
   - `lib/screens/platform_admin/**`: the operator console, used only by the platform owner.
   - `lib/screens/legal/**`: privacy policy and terms need a legal translation, not a drafted one.
   - Receipts, PDFs and the thermal printer: language is a facility setting (a later feature).
   - Server error messages (`HttpsError` text from `functions/`): shown as they arrive. List them in the report as a future item (error codes).
   - Technical text: debug logs, asset paths, route names, field names, and `debugPrint`.

## 3. Setup (batch 2F-0, no screen text yet)

- `pubspec.yaml`: add `flutter_localizations` (sdk) and `generate: true`. This is the only pubspec change allowed in this step.
- `l10n.yaml`: `arb-dir: lib/l10n`, `template-arb-file: app_en.arb`, `output-localization-file: app_localizations.dart`. Follow Flutter's current guidance for the installed version on where generated files go, and commit them only if Flutter writes them into `lib/`.
- `MaterialApp`: `localizationsDelegates: AppLocalizations.localizationsDelegates`, `supportedLocales: AppLocalizations.supportedLocales`, `locale:` from `UiSettingsProvider`.
- `lib/l10n/l10n.dart`: `extension` giving `context.l10n`, and `L10n.current`.
- Tests: switching the locale changes the text a widget shows; `L10n.current` follows the provider; the saved locale survives a restart (reload from storage).
- Exit: the app runs in English exactly as before, and a test string can be switched to Kiswahili.

## 4. Keys

- Name: `<area>_<element>`, in lowerCamel after the underscore: `sales_saveButton`, `team_rejectConfirmTitle`, `login_wrongCredentials`. Area is the folder or feature.
- Shared words: `common_save`, `common_cancel`, `common_delete`, `common_search`, `common_close`, `common_retry`, `common_yes`, `common_no`, `common_details`, `common_copy`, `common_loading`, and so on.
- Before creating a key, search the ARB for the same English text. **Reuse, do not duplicate.** Two identical English strings with different meanings (for example "Order" the noun and the verb) get separate keys.
- Every key in `app_en.arb` has an `@key` entry with a `description` (where it appears) and, where it has placeholders, their types.

## 5. Extraction rules

- **Placeholders, never concatenation.** `Text('Sold ${n} items to $name')` becomes one key with `{count}` and `{name}`.
- **Plurals** use ICU: `{count, plural, =0{No items} =1{1 item} other{{count} items}}`.
- **Amounts are pre-formatted.** Pass `Money.format(x)` (a string) as a placeholder; do not let the language file format numbers.
- **The app name** is the placeholder `{appName}` (from `AppInfo.name`), not typed text.
- **Feedback messages** (`AppFeedback.*`) use `L10n.current.<key>`; their title and second line are two keys.
- **`FriendlyError`** messages become keys (`error_noPermission`, `error_noConnection`, `error_tooSlow`, `error_notFound`, `error_alreadyExists`, `error_rateLimited`, `error_generic`, and the sign-in ones). Behaviour is unchanged. The raw error still appears only behind Details.
- **Sign-in messages** (`auth_error_messages.dart`) become keys with identical English text.
- Leave a string in English, and allowlist it with a reason, only if it is in section 2.8.
- Do **not** reword English text while moving it. If the wording is poor, list it in `docs/design-open-questions.md`.

## 6. Stored values shown to people

Several lists are stored as English values but shown on screen: product categories, product types, product units, service categories, facility types, payment methods (`PaymentMethod.label`), activity types, restock frequencies, and role and status names.

- Keep the stored value exactly as it is.
- Add a display lookup per list, for example `L10n.productCategoryLabel(String stored)`, that returns the localised label for a known value and **returns the stored text unchanged for any unknown or custom value**.
- Dropdowns, filters and chips use the lookup for what they show, and the stored value for what they save and compare.
- Add a test per list that every known stored value has a label in both languages.

## 7. Guard

- Switch on rule **R10** (raw user-facing string) with today's counts as the baseline (about 1,651). It only falls.
- The guard's R10 pattern covers `Text(`, `SnackBar`/`AppFeedback` message arguments, `labelText:`, `hintText:`, `title:`, `tooltip:`, `semanticLabel:` and similar with a string literal. Extend it if you find a text-bearing parameter it misses, and say so in the report.
- Out-of-scope folders (2.8) get **folder-level allowlist entries with the reason**, not per-line entries.
- The step is done when R10 is zero or allowlisted with a reason.

## 8. Kiswahili: drafting and review

- Draft natural, everyday Tanzanian Swahili that a shopkeeper or vet would use. Short and clear beats formal. Keep the tone of the English.
- **Starter glossary** (a suggestion, the owner corrects it; keep terms consistent across the app): Sales = Mauzo, Products = Bidhaa, Clients = Wateja, Debts = Madeni, Services = Huduma, Payments = Malipo, Reports = Ripoti, Settings = Mipangilio, Save = Hifadhi, Cancel = Ghairi, Delete = Futa, Search = Tafuta, Stock = Stoo/Akiba, Shelf = Rafu, Staff = Wafanyakazi, Assistant = Msaidizi, Facility = Kituo, Trash = Takataka/Tupio, Receipt = Risiti.
- Mark every Kiswahili entry as a draft in the `@key` metadata of `app_sw.arb` (for example `"x-review": "draft"`).
- **Review file for the owner:** `tool/export_l10n_review.dart` writes `docs/kiswahili_review.csv` with the columns `key, english, kiswahili, notes, status`. The owner edits it in Excel. `tool/import_l10n_review.dart` reads the edited file back, updates `app_sw.arb`, and marks reviewed rows `reviewed`. Never overwrite an owner edit with a draft.
- **Tests (`test/l10n_test.dart`):** every key exists in both files; no empty values; placeholders and plural arguments match between English and Kiswahili for every key; and a count of entries still marked `draft`, printed (not failing), so progress is visible.
- Do **not** present drafted Swahili as final in any report.

## 9. Work plan

One commit per batch, none over 300 lines, in this order. Stop after 2F-0 and after 2F-1 for the owner's go-ahead; after that, continue batch by batch.

- **2F-0** Setup, `locale` setting, the rewired Language picker, `L10n.current`, tests (section 3).
- **2F-1** Common keys; `FriendlyError`, `AppFeedback` standard texts, sign-in messages; the first Kiswahili draft of those; the export and import tools; `l10n_test`; R10 on with its baseline. The owner reviews this batch in the CSV before the rest.
- **2F-2** `lib/widgets/**` and `lib/utils/**`.
- **2F-3** the stored-value lists and their lookups (section 6).
- **2F-4 onward**, by folder, in the order of the earlier D batches: payments, subscription, store; transactions, debtors, clients; admin, settings; reports, services; products, sales; login and register; dashboard; facilities; activity.
- **Final:** the guard report, the Kiswahili draft count, and the list of strings kept in English with reasons.

After each batch: `flutter analyze` with no errors and no new infos, "All tests passed", then tell the owner what to look at in Chrome **in both languages** (switch the language in Settings and open the screens of that batch).

## 10. Report (under 40 lines)

```
Batch:
Commit:
Keys added (new / reused):
Strings moved (R10 before -> after):
Kept in English, with reason:
Wording problems noticed (not changed):
Kiswahili entries: drafted n | reviewed n
flutter analyze:  before -> after
flutter test:     passed / failed
What to check in Chrome (both languages):
```

## 11. Risks

| Risk | Handling |
|---|---|
| Layout overflows because Swahili text is longer | Check each batch in Chrome in Kiswahili at a narrow width; use `Flexible`/wrapping where it overflows, and report each change |
| Translating a stored value corrupts history | Section 5.5 and section 6: display lookups only |
| A drafted translation is wrong or awkward | Review CSV before the rest of the app moves over |
| Missing key in one language | `l10n_test` fails |
| Duplicate keys for the same words | Search before adding; reuse `common_` keys |
| Mixed languages on one screen | Each batch converts whole screens |

## 12. Definition of done

- R10 is zero outside the allowlisted folders, which carry reasons.
- `l10n_test` passes; every English key has a Kiswahili entry.
- The owner has reviewed the Kiswahili in the CSV (or the remaining drafts are listed).
- The Language picker in Settings switches the whole app, and the choice survives a restart.
- Stored data, dates, numbers, receipts and PDFs are unchanged.
- `CLAUDE.md` (on disk, never committed) is updated with the key rules.
