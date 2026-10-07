# Phase 2 addendum: uniform user feedback (snackbars, toasts, errors)

**For:** Claude Code. **Owner:** Shanel. **Part of:** `docs/PHASE2_SPEC.md` (this adds a step; every rule in section 0 of that file still applies).
**Written against:** commit `76ce094`.

---

## 1. Why this exists

The main spec treats snackbars only as text to translate and as a duration token. It does not make them consistent. Audit at `76ce094`:

| Finding | Count |
|---|---|
| `showSnackBar` calls | 192 in 42 files |
| Shared helper | none |
| No colour set (plain dark grey bar) | 65 |
| Errors in three different reds (`redAccent` 52, `red` 15, `dangerColor` 6) | 73 |
| Green success (`Colors.green` 43, `success` 4) | 47 |
| Icon, floating card, rounded shape, width limit, action button | 0 of 192 |
| Duration set (the rest use Flutter's default) | 9 |
| Show **raw exception text** to the user (`Failed to save service: $e`) | 71 |
| Messages that say "successfully" | 11 |
| Messages with no end punctuation / with `.` / with `!` | 146 / 24 / 4 |
| Messages starting "Error" or "Failed" | 19 |

On a wide screen each one is a full-width bar across the whole window.

## 2. Decisions (made, do not reopen)

1. **One entry point, `AppFeedback`.** App code never calls `ScaffoldMessenger`, `SnackBar` or `showSnackBar` directly (guard rule R11, section 9).
2. **Built on Flutter's `SnackBar`,** not a custom overlay. That keeps Flutter's queueing, animation, accessibility and safe-area handling. Use `behavior: SnackBarBehavior.floating`, `backgroundColor: Colors.transparent` (allowed inside `lib/ui/feedback/`), `elevation: 0`, zero padding, and a custom card as the content.
3. **No `BuildContext` needed.** Put a `GlobalKey<ScaffoldMessengerState>` on `MaterialApp.scaffoldMessengerKey` (exposed as `AppFeedback.messengerKey`). Calls such as `AppFeedback.success('Saved')` then work after an `await`, and after the screen is gone. This removes the context-after-await problem for feedback calls (part of the 42 `use_build_context_synchronously` infos).
4. **Look:** a floating card, bottom-centre, one at a time. A new message **replaces** the current one (call `clearSnackBars()` first). Never queue.
5. **Four types plus Undo:** success, info, warning, error, and `undo`. Colours come from `AppColors` roles, so Dark Mode and colour themes work later.
6. **Errors never show raw exception text.** A friendly message is shown. The technical detail is behind a **Details** action, which copies it. The raw error is always `debugPrint`ed.
7. **Soft deletes get Undo.** The app already has a Trash, so Undo is real.
8. **Text is passed in by the caller** as a ready string. Step 2F (localisation) replaces the string literals with l10n keys.

## 3. Look and behaviour

| Aspect | Spec |
|---|---|
| Position | Bottom-centre. Above the bottom safe area; clear of the floating action button where one exists |
| Width | Full width minus `AppSpacing.s12` on each side on compact screens; otherwise `AppSizes.toastMax` (**new token, 400**) |
| Surface | `colors.surface` card, `AppRadius.r12`, 1px `colors.borderStrong` border, `AppElevation.e2` |
| Icon | 28px circle: `AppColors` role at `AppAlpha.a10` as the fill, the role colour for the glyph (`AppIconSize.i16`). Glyphs: success `check`, info `info_outline`, warning `warning_amber_rounded`, error `error_outline`, undo `delete_outline` |
| Text | Title: `AppFontSize.f14`, `AppFontWeight.semibold`, `colors.textPrimary`, up to 2 lines. Optional second line: `AppFontSize.f13`, `colors.textSecondary` |
| Actions | Text buttons on the right: optional Details, optional primary action (Undo or Retry, `colors.primary`, semibold), and a close icon (`AppIconSize.i16`). Each at least 40px high |
| Roles | success → `success`; error → `danger`; warning → `warning`; info → `primary`; undo → neutral (`surfaceMuted`, `textSecondary`) |
| Motion | Fade and rise of 12px in `AppMotion.fast` |
| Accessibility | `Semantics(liveRegion: true)` with the message as the label; close and action buttons labelled; respects reduced motion |

**Durations** (new `AppMotion` tokens): `toastSuccess` 3 s, `toastInfo` 4 s, `toastWarning` 5 s, `toastUndo` 6 s, `toastError` 7 s. The older `toastShort` (2 s) and `toastLong` (3 s) are removed once nothing uses them. A message with an action stays while the pointer is over it.

## 4. API

```dart
AppFeedback.success('Product saved');
AppFeedback.info('Recalculating smart defaults\u2026');
AppFeedback.warning('Select a client to record a partial payment');
AppFeedback.error("Couldn't save the product", error: e, stackTrace: st, onRetry: _save);
AppFeedback.undo('Client moved to Trash', onUndo: _restoreClient);
```

- `error`'s second line is `FriendlyError.messageFor(error)` unless an explicit `detail:` is given.
- `onRetry` adds a **Retry** action. `error:` adds a **Details** action (shows and copies `code and message`).
- Every method returns `void`, is safe to call at any time, and does nothing if the messenger isn't mounted yet.

## 5. Friendly errors: `lib/ui/feedback/friendly_error.dart`

`FriendlyError.messageFor(Object error)` returns a one-sentence message:

| Error | Message |
|---|---|
| `FirebaseException` `permission-denied` | You don't have permission to do that. |
| `unavailable`, network failures | No connection. Check your internet and try again. |
| `deadline-exceeded`, `TimeoutException` | That took too long. Try again. |
| `not-found` | That item no longer exists. |
| `already-exists` | That already exists. |
| `resource-exhausted` | Too many requests. Wait a moment and try again. |
| `FirebaseFunctionsException` with a message from our server | **The server's own message**, unchanged. The `HttpsError` texts in `functions/membership.js` are written for people (for example "You've reached the limit…"). Exception: code `internal` uses the fallback |
| `FirebaseAuthException` | Reuse the mapping the login and register screens already have. Do not write a second one |
| anything else | Something went wrong. Try again. |

- Unit-test every row, including that **no output contains** `Exception`, `cloud_firestore`, `[`, or a stack trace.
- Details text is `code` and `message`, shown only after the user taps Details.

## 6. Copy rules (the words)

- Sentence case. No full stop at the end of a title. No `!`. No "please". No "successfully". No "Error:" or "Failed to".
- Success: **past tense, the thing and what happened.** "Product saved", "Payment recorded", "Client moved to Trash".
- Error: **what happened, then what to do,** one sentence each. Title: "Couldn't save the product". Second line: from `FriendlyError`.
- Warning: **name the next step.** "Select a client to record a partial payment".
- Ellipsis only for something in progress: "Recalculating smart defaults\u2026".
- Do not invent facts or change meaning. If a message's meaning is unclear, keep its words and list it in `docs/design-open-questions.md`.

Examples from the audit:

| Today | Becomes |
|---|---|
| `Failed to save service: $e` | Title "Couldn't save the service", second line from `FriendlyError`, **Details** for the raw error |
| `Could not delete client: $e` | "Couldn't delete the client" (+ friendly line, Details) |
| `Product saved successfully!` | "Product saved" |
| `Please select a client to record this as a partial payment, or choose Walk-in Customer ` | Warning: "Select a client, or choose Walk-in Customer" |
| `Logo updated` | "Logo updated" (already right) |
| `Recalculating smart defaults from usage history...` | Info: "Recalculating smart defaults\u2026" |

## 7. When not to use a toast

- **A field is wrong:** show the error under the field.
- **The user must decide:** a dialog.
- **A standing condition** (maintenance mode, subscription state): a banner. Out of scope here.
- **Before a destructive action:** a confirmation dialog, then the toast with Undo afterwards.

## 8. Undo for deletes

Use `AppFeedback.undo` only where the deletion is a **soft delete** into a `trash_*` collection. The restore logic already exists in `trash_screen.dart`; reuse it, do not duplicate it. List the deletes you find (client, product, sale, service, payment, …) and, for each, whether Undo is straightforward. Where restore can't be called without changing behaviour, use `success` instead and add the case to `docs/design-open-questions.md`. Hard deletes keep their confirmation dialog and a plain success toast.

## 9. Guard

Add rule **R11: raw feedback call**: `\bshowSnackBar\(`, `\bSnackBar\(`, `ScaffoldMessenger\.of`, outside `lib/ui/feedback/**`. Baseline today's counts. It must fall to 0 by the end of 2D.

## 10. Migrating the 192 calls

1. Classify by the colour the call uses today: green or `success` → `success`. `red`, `redAccent`, `dangerColor` → `error`, or `warning` if the message is only a validation prompt ("Select…", "Enter…", "Please…"). Orange → `warning`. No colour → `info`, or `warning` if it asks the user to do something.
2. A message containing `$e`, `e.toString()` or an error variable → `AppFeedback.error(<title without the exception>, error: e, stackTrace: st)`.
3. Rewrite the wording by section 6. Keep the meaning.
4. Replace `ScaffoldMessenger.of(context).showSnackBar(SnackBar(...))` entirely. Do not keep any `backgroundColor`, `duration` or `behavior`.
5. If an `if (!mounted) return;` guard existed **only** to protect the snackbar, it may go. Keep it if anything else after it uses `context`.
6. Do it **inside the 2D screen batches**, in the files each batch already opens. No separate pass over the app.
7. In the report, list: counts per type, every message reworded (old → new), and every call that kept its original words.

## 11. Work plan

**Step 2D-0: Feedback foundation** (after 2C, before 2D batch D1)
- Create `lib/ui/feedback/app_feedback.dart` and `friendly_error.dart`. Add `scaffoldMessengerKey` in `main.dart`. Add the new tokens (`AppSizes.toastMax`, the five `AppMotion` durations).
- Add the guard rule R11 and its baseline.
- Tests: `test/app_feedback_test.dart` (widget test with a `MaterialApp` and the key): one at a time; a new message replaces the old; Undo callback fires and dismisses; auto-dismiss at the right time (use `tester.pump` with durations); an error built from `Exception('[cloud_firestore/permission-denied] x')` never shows that text on screen; the Details action reveals it. `test/friendly_error_test.dart`: every row of section 5.
- **Convert three representative screens first** and stop for the owner to look at the result in Chrome before the rest: the add-sale screen (success and warning), client deletion (undo), and the subscription form (error with Details).
- Exit: analyze at or below baseline; tests pass; the owner's approval of how it looks.

**Then, inside every 2D batch:** replace that batch's snackbars (section 10). R11 falls with each batch.

## 12. Definition of done (addition to the main spec)

- R11 is 0 outside `lib/ui/feedback/`.
- No user-facing message contains raw exception text.
- All feedback in the app has the same look, position, durations and wording style.
- The owner has seen all five types, including Undo, on desktop and a narrow window.

## 13. Decisions for the owner (defaults chosen; say if you want any changed)

- Position: bottom-centre. (Alternative: top-right on wide screens.)
- Error toasts stay 7 seconds. (Alternative: until dismissed.)
- Undo is offered only for soft deletes.
