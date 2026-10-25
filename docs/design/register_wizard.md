# RW1: the register screen as a step-by-step wizard

Batch RW1 (RUNBOOK2 ledger), a DESIGN STOP: no code is changed. RW2a to RW2c implement it once the last line says APPROVED.
Owner request: registration becomes a wizard inside the same card as login: "Step 1 of N" with the step title at the right, a thin progress bar, one question or group per step (large title, short grey subtitle), big option cards with a radio, Back and Continue at the bottom of the card. Theme roles and our logic. Code read at `23358ff`; lines are `lib/screens/register_screen.dart` (2,216 lines) unless named.

## 1. Current state

**One screen, two modes.** `isUpdating` picks `_buildEditView` (Edit Profile, :1084) or `_buildRegisterView` (:811: `AuthBackground` + `AuthCard`, welcome panel 290 px beside the form above `AppBreakpoints.medium`, a welcome strip above it below). The form (`_buildRegisterForm` :1013) shows every section at once: Personal (:1508), Role (:1626), Facility (:1746), Security (:2037), the terms line (:1067), Create account (:1463). Edit Profile reuses Personal, Role (locked) and Facility (read only) and is **not** part of this redesign.

| Field (state) | Owner | Assistant | Check before submit (`_validateAll` :1235) |
|---|---|---|---|
| Photo (`_imageBytes`, :150; `ProfilePhotoEditor` :1597) | optional | optional | none; `pickPhoto` scales and size-checks (G2) |
| Title (`selectedPrefix` :146, Mr./Mrs./Ms./Dr.) | yes | yes | always set |
| Full name (`nameController` :63) | yes | yes | empty -> `register_enterFullName`; < 2 -> `register_nameTooShort` |
| Email (`emailController`) | yes | yes | empty / `_emailPattern` (:1207) |
| Phone (`phoneController`) | yes | yes | empty / `_isPlausiblePhone` (:1226, 9 to 15 digits) |
| Role (`selectedRole` :147, stored client values 'Admin'/'Assistant') | 'Admin' | 'Assistant' | `_selectRole` (:1612) clears the assistant fields |
| Facilities (`facilities` list, `facilityNameController` :141, `_selectedFacilityType` :142) | 1 to `_maxFacilities` | - | none added: three messages incl. "press Add" (:1263) |
| Invite code (`assistantFacilityCodeController` :73, `_foundFacility` :81) | - | yes | empty / still checking / not found or the lookup error (:1276) |
| Password, confirm (`PasswordFieldGuard _password, _confirm` :68) | yes | yes | `_passwordIssue` (:409: 8+, a letter, a number, not common); must match |

**Calls and side effects, in order.**
- *As typed (assistant):* `_onFacilityCodeChanged` (:86) debounces (`AppTimeouts.facilityLookupDebounce`) then calls `MembershipService.checkInviteCode` (`membership_service.dart:60`, callable `checkInviteCode`). Valid -> `_foundFacility` {name, type, code}; invalid -> `register_inviteInvalid`; `resource-exhausted` -> the server's text "Too many wrong invite codes. Wait 15 minutes and try again." (`functions/membership.js:51`, 5 failures in 15 minutes, by uid or hashed IP); any other error -> `register_inviteCheckFailed`. The check does not reserve the code.
- *Add facility (owner):* `addFacility` (:362) warns on a missing name or type and at the limit (`_maxFacilities`, live from `streamMaxFacilitiesPerAdmin`, :248); `generateUniqueFacilityCode` is local (`Random.secure`, no network).
- *Create account:* `_submitGuarded` (:641: one run at a time, spinner) -> `_validateForm` (:1328: every field flagged, a toast summary `_summaryFor` :1307, scroll to the first) -> `_submit` (:417).
  - Owner: `AuthService.registerOwnerAccount` (`auth_service.dart:91`): a temporary Firebase app creates the Auth account, sends the verification email (failure ignored), calls `registerOwner` (profile + facilities + trial, the server checks the limit); a server failure deletes the bare account and rethrows; then the main session signs in, and a failed sign-in throws `AccountCreatedException` (:135, `register_accountCreatedSignIn`). Then the photo `savePhoto` (failure only logged), the success toast, and one facility -> `activateFacilityAndGoToDashboard`, several -> `FacilityPickerScreen` (:511-536).
  - Assistant: `registerAssistantWithInvite` (`auth_service.dart:144`): temporary app, account, verification email, photo upload as the new account, `joinWithInvite` (redeems the code, status pending); failure deletes the bare account. Not signed in: toast, then `/login` (:539-566).
- *Errors (:568-611):* every failure first runs `_clearPasswordsAfterFailure` (:238, P1b: both fields emptied and hidden). `email-already-in-use` / `invalid-email` -> the email field error + toast; `weak-password` -> the password field; other Auth errors -> `register_createFailed`; callable errors -> `MembershipService.errorMessage`, and for an assistant `failed-precondition` also the invite field and `_foundFacility = null`; anything else -> `AccountCreatedException.message` or `FriendlyError`.
- *Terms:* a passive line "By creating an account you agree to our Terms of Service and Privacy Policy" with links (:1067); nothing is stored.
- *P1b guards:* the eyes close after `AppTimeouts.passwordReveal`, on blur and when the app leaves the foreground (`password_field_guard.dart`).

**State a wizard must keep across Back** (all live in `_RegisterScreenState`, so one State keeps them): the controllers above, `selectedPrefix`, `selectedRole`, `facilities` and the half-typed facility name/type, `_foundFacility` / `_facilityLookupError`, `_imageBytes`, `_fieldErrors`, `_submitAttempted`, `_maxFacilities`. New: `_step`.

## 2. The steps

Both flows have 5 steps; step 1 decides the flow. **Continue checks only the step's own fields** (the `_validateAll` entries for those keys): each error under its field in the existing wording, focus on the first; no toast for field errors. Back never clears anything. Nothing reaches the server before the last step except the invite check, which already runs as the code is typed. The last step runs the existing `_submitGuarded` / `_submit` unchanged.

| # | Owner | Assistant | Blocks Continue |
|---|---|---|---|
| 1 | **How will you use {appName}?** Option cards: "I own or manage a facility" / "I have an invite code" (the existing role card texts) | same | nothing (Owner preselected, as today) |
| 2 | **About you:** photo (optional), title, full name, phone | same | name, phone |
| 3 | **Your facility:** name, type as option cards (Agrovet, Vet Clinic, Vet Hospital, Ambulatory Vet, Other through `facilityTypeLabel`), Add, the list with remove, the limit | **Your invite code:** the code, the live check, "You're joining {facility} ({type})" | owner: no facility (incl. "press Add" when one is typed); assistant: empty, still checking, not found, too many tries |
| 4 | **Sign-in details:** email, password, confirm (P1b guards) | same | email, password, confirm |
| 5 | **Check and create:** a summary per step with "Change" (jumps to it), the terms line, **Create account** in place of Continue | same, Create account | the whole `_validateForm` once more (a jump to the first step with a problem) |

Switching role in step 1 after step 3 was filled keeps today's rule (`_selectRole` clears the assistant fields; facilities stay).

## 3. The layout

- **Card:** the shared `AuthCard` (G1), unchanged size. Wide (above `twoPane`): the welcome panel at the left as today, the wizard at the right. Narrow: no welcome strip after step 1 (question 2).
- **New shared widgets (RW2a, `lib/widgets/wizard/`, roles and tokens only):** `WizardStepHeader` ("Step {n} of {total}" in `textMuted` at the left, the step title at the right in `textPrimary`, wrapping under it when narrow; a 4 px `LinearProgressIndicator`, `primary` on `divider`, animated `AppMotion.fast`); `WizardStepIntro` (title `AppFontSize.f22` bold `textStrong`, subtitle `f14` `textMuted`); `WizardOptionCard` (radio + title + optional subtitle and icon, 56 px min, `selectedCardFill` / `selectableCardInk` and a `primary` border when chosen, the K6 roles; whole card tappable, `Semantics(selected)`); `WizardNavBar` (Back outlined at the left, hidden on step 1; Continue filled `primary` at the right; both 48 px; Continue shows a spinner and both disable while submitting).
- **Continue** stays enabled and shows the errors when tapped (recommended over disabled, which does not say why; question 3).
- **Keyboard:** `TextInputAction.next` through a step's fields, `done` on the last, whose `onSubmitted` = Continue; Enter in any field does the same on desktop. On phones (below `compact`) `WizardNavBar` is pinned at the bottom of the screen above the keyboard (`Scaffold.bottomNavigationBar` padded by `viewInsets`), so the keyboard never hides Continue; wider it is the card's bottom row.
- **Focus:** a new step focuses its first empty field (none on option steps); a failed Continue focuses the first error and scrolls it into view (`_scrollToField`).
- **Back gesture:** `PopScope(canPop: _step == 0)`; a phone back gesture or the browser Back on step 2+ goes one step back. Step 1 Back leaves as `_goBack` (:654) does today.
- **Text:** no `maxLines` on titles, subtitles or option cards; Kiswahili wraps. Dark Mode is role-only (the K roles), nothing new.
- **Widths:** 360 and 390: card = screen minus 2 x 24, padding 18, bar pinned at the bottom; 768: the 560 card, the bar in the card; 1200: the 1100 card, welcome panel 290 + wizard.

## 4. Edge cases

- **Reload in the middle:** nothing is kept; the page starts at step 1. Passwords are never stored anywhere (no SharedPreferences or browser storage for this screen; a test pins it). Keeping the other answers is possible but not proposed (question 9).
- **Email already in use at the last step:** go to step 4, the email field shows `register_emailAlreadyRegistered`, the password fields are empty (P1b) and the person types them again. Same for `invalid-email` (step 4) and `weak-password` (step 4, password field).
- **Wrong invite code / too many tries:** shown under the code on step 3 as today; Continue blocked. The server's rate-limit text is English (server text, spec 2.8).
- **Back after the code was checked:** `_foundFacility` stays; editing the code re-checks. The code may expire or be used before Create: `failed-precondition` -> step 3 with the server's message and `_foundFacility = null`.
- **Failed submit, any other cause:** the passwords are emptied (P1b), so go to step 4 with the toast (`register_createFailed` / `FriendlyError` / the server's message). `AccountCreatedException` (account made, sign-in failed): stay on step 5 with its message, which already says to sign in (question 7).
- **Network loss:** the check shows `register_inviteCheckFailed`; a submit fails as above; the owner path's server failure already deletes the bare account, so a retry works. A double tap is stopped by `_submitGuarded`.
- **Facility limit changed by a Platform Admin mid-way:** `_maxFacilities` is live; the server enforces it anyway.

## 5. Tests, batches and questions

**Tests that fail today and pass after** (new `test/rw2_register_wizard_test.dart`, with the services injected: `RegisterScreen` gets optional `authService` and `membershipService`, as `LoginScreen` has):
1. On open: "Step 1 of 5", the two option cards, only Continue (no Back); no name or password field on screen.
2. Continue on an empty step 2 stays on step 2, flags name and phone only, focuses name; step 4 fields are not flagged.
3. Back from step 4 to 2 and forward keeps every value (passwords included, hidden); the system back (`handlePopRoute`) on step 3 shows step 2.
4. Owner happy path: the fake `registerOwnerAccount` is called once, only after Create, with exactly the arguments of today; the fake invite check is never called.
5. Assistant path: typing the code calls the fake check; Continue is blocked while checking and when invalid; the rate-limit text shows under the field; Create calls `registerAssistantWithInvite` once.
6. `email-already-in-use` from the fake: step 4, the email error, both password fields empty. `failed-precondition` for an assistant: step 3, the invite error.
7. Enter on the last field of a step continues; at 360 with a simulated keyboard (`viewInsets` 300) Continue is on screen.
8. No overflow at 360, 390, 768, 1200, in Light and Dark, English and Kiswahili, with a long name and facility name.
9. Source check: no SharedPreferences or browser storage in `register_screen.dart` and `lib/screens/register/`.

**Existing tests:** `g1_auth_look_test` (same card width, the toggle, no image, no overflow) must keep passing unchanged; `g2_profile_test` source checks unchanged; `facility_codes_test` counts `['code']` in `register_screen.dart` (2): if the steps move to `lib/screens/register/`, the allowed entry moves with them (same count, same reason). No current test drives the register form fields, so none breaks for a field moving.

**Batches** (each commit 300 lines or fewer, tests first and skipped, every gate after every commit):
- **RW2a shared widgets and seams:** the four wizard widgets with their tests (sizes, roles in Light/Dark, wrapping in Kiswahili), the service seams, the new ARB keys (step titles, subtitles, "Step {current} of {total}", Back, Continue, Create account reused) with Kiswahili drafts and the export. No screen changes. Not a hard stop.
- **RW2b owner flow:** the register view becomes the wizard for the owner (steps 1 to 5), the section builders split into step widgets (likely `lib/screens/register/` part files, so the 2,216-line file shrinks), Edit Profile untouched. **HARD STOP:** the owner signs up an owner in Chrome and on the phone (one facility -> dashboard, two -> picker), email in use, Back and the back gesture.
- **RW2c assistant flow:** steps 3 and 5 for the assistant, the invite cases, the rate limit. **HARD STOP:** an assistant signs up with a real invite, a wrong code, too many tries, then pending approval.

**Questions only the owner can answer:**
1. Terms: keep the passive line on step 5, or a required "I agree" checkbox that blocks Create?
2. Wide window: keep the welcome panel beside the wizard, or the wizard alone, centred in the card? Narrow: drop the welcome strip after step 1?
3. Continue always enabled showing errors (recommended), or disabled until the step is valid?
4. Five steps, or four (email and password joined with "About you")?
5. Keep the review step 5, or create from step 4?
6. Facility type as option cards (recommended, the mockup's style) or the dropdown as today? And the title (Mr./Mrs./Ms./Dr.) as a dropdown or chips?
7. `AccountCreatedException`: stay on step 5 with the message, or take the person to Sign in with the email filled in?
8. Edit Profile stays the one-page form (recommended), or a wizard too?
9. Nothing kept after a reload (recommended), or keep the non-secret answers for the session?
10. Phones: the Back/Continue bar pinned to the bottom of the screen above the keyboard (recommended), or kept at the bottom of the card?

OWNER DECISION: PENDING
