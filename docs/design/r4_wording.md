# R4 wording pass (D9): every candidate

Sources: decision D9 (`docs/RUNBOOK2.md` section 2), the wording notes in `docs/L10N_STATUS.md` and `docs/design-open-questions.md` ("Raised in step 2F" and E4b2), and a count of the English ARB (`lib/l10n/app_en.arb`, values only, not the `@` descriptions).

Rule for (b), a pair of spellings of the same thing: applied only when the more common spelling has at least 3 occurrences and at least twice the other's. Anything else is left for the owner with its counts.

"Meaning?" = does the change alter what the text means. Keys never change; stored values never change.

## A. Applied: D9 (sign in / sign out, All Statuses, capital slips)

| Key | Current English | Proposed English | Reason | Meaning? |
|---|---|---|---|---|
| common_logout | Logout | Sign out | D9 verb | No |
| common_logIn | Log in | Sign in | D9 verb (register screen) | No |
| login_loginButton | Login | Sign in | D9 verb (the sign-in button) | No |
| login_logIntoFacility | Log into your facility | Sign in to your facility | D9 verb (sign-in form subtitle) | No |
| facilityPicker_logOut | Log Out | Sign out | D9 verb; "Sign out" is the app's standalone button (common_signOut, common_logout: 2, "Sign Out": 0) | No |
| dashboard_logoutConfirm | Are you sure you want to logout? | Are you sure you want to sign out? | D9 verb | No |
| account_logoutAllTitle | Log Out of All Devices? | Sign Out of All Devices? | D9 verb (title case kept, as the Manage Account titles) | No |
| account_logoutAll | Log Out of All Devices | Sign Out of All Devices | D9 verb | No |
| account_logoutEverywhere | Log Out Everywhere | Sign Out Everywhere | D9 verb | No |
| account_logoutAllBody | ...and log you out on all other phones... | ...and sign you out on all other phones... | D9 verb | No |
| team_deactivateBody | ...and can't log in until you reactivate them... | ...and can't sign in until you reactivate them... | D9 verb | No |
| team_noAdmin | No logged in admin user found | No signed-in admin user found | D9 ("logged in") | No |
| account_wipeBody | ...Your login credentials remain unaffected. | ...Your sign-in credentials remain unaffected. | D9 ("login" as a noun) | No |
| account_wipeHint | ...while keeping your log in profile. | ...while keeping your sign-in profile. | D9 ("log in" as a noun) | No |
| products_statusAll | All Status | All Statuses | D9 filter (stock status list; compares 'All', unchanged) | No |
| entry_couldNotLoadTitle | Could Not Load Your Account | Couldn't load your account | D9 capital slip (sentence case as the other titles) + (b) Couldn't | No |
| register_askAdminForInvite | Ask your facility Admin for an invite code... | Ask your facility admin for an invite code... | D9 capital slip; "facility admin" 2, "facility Admin" 1 | No |
| activity_retentionNoPermission | the security rules don't currently allow deleting logs | The security rules don't currently allow deleting logs | D9 capital slip (on Facilities it is a line of its own; on Activity Log it follows "yet: ") | No |

Screen title "Sign in": the sign-in screen has no "Login" title in the ARB (its title is "Welcome back"; the browser tab says `vetbiz_pro` from `web/index.html`, not ARB). Nothing else to change.

## B. Applied: (b) "Could not" -> "Couldn't" at the start of a message

Counts (start of a value): "Couldn't " 69, "Could not " 15 (+1 "Could Not", above). Mid-sentence uses are in section D.

| Key | Current English | Proposed English | Meaning? |
|---|---|---|---|
| error_couldNotLoad | Could not load data | Couldn't load data | No |
| subscription_historyLoadError | Could not load history: {error} | Couldn't load history: {error} | No |
| clients_loadError | Could not load clients: {error} | Couldn't load clients: {error} | No |
| invite_checkFailed | Could not check for an existing invite: {error} | Couldn't check for an existing invite: {error} | No |
| invite_generateFailed | Could not generate an invite: {error} | Couldn't generate an invite: {error} | No |
| invite_revokeFailed | Could not revoke: {error} | Couldn't revoke: {error} | No |
| searchIndex_failed | Could not complete: {error} | Couldn't complete: {error} | No |
| batch_saveFailed | Could not save: {error} | Couldn't save: {error} | No |
| batch_deleteFailed | Could not delete: {error} | Couldn't delete: {error} | No |
| batch_loadFailed | Could not load batches: {error} | Couldn't load batches: {error} | No |
| register_inviteCheckFailed | Could not check this code - try again | Couldn't check this code - try again | No |
| noFacility_deleteFailed | Could not delete the account. | Couldn't delete the account. | No |
| noFacility_deleteFailedWith | Could not delete the account: {error} | Couldn't delete the account: {error} | No |
| notifications_loadFailed | Could not load alerts: {error} | Couldn't load alerts: {error} | No |
| membership_unreachable | Could not reach the server - check your connection and try again. | Couldn't reach the server - check your connection and try again. | No (the two-sentences question stays, D) |

Kiswahili: the sign-in and sign-out drafts already say "Ingia"/"Toka" (unchanged). Changed to match: register_askAdminForInvite "Msimamizi" -> "msimamizi"; entry_couldNotLoadTitle "Imeshindwa Kufungua Akaunti Yako" -> "Imeshindwa kufungua akaunti yako"; activity_retentionNoPermission "kanuni" -> "Kanuni"; the four "Imeshindikana" drafts of section B (error_couldNotLoad, batch_save/delete/loadFailed) -> "Imeshindwa", the form of 52 of the 69 "Couldn't" drafts (17 say "Imeshindikana"). All stay `draft`.

## C. Not ARB (found, left for the owner)

| Where | Text | Why left |
|---|---|---|
| lib/services/auth_service.dart:133 (AccountCreatedException, shown on Register) | "...Please log in with your email and password." | Not in the ARB at all (a missed string, English in both languages); moving it is a code change. Owner: move to the ARB as "...Please sign in with your email and password."? |
| lib/screens/platform_admin/platform_admin_home_screen.dart:222, 239, 530 | "Logout?", "Logout" | Operator console, English only (spec 2.8), not ARB |
| lib/screens/platform_admin/user_detail_screen.dart:243-244, 303 | "log in", "account and login" | Operator console, not ARB |
| lib/screens/legal/ (privacy, terms) | "login", "login credentials" | Legal text: never reworded here |
| Route '/login', value 'logout', key names (login_*, common_logout...) | technical | Not shown; keys never change |

## D. Owner decisions (not applied: tie, meaning, or a sentence rewrite)

| Candidate | Counts / note | Why not applied |
|---|---|---|
| "Move to Stock" / "Remove from Sellable" | 1 / 1 | D9: different actions, stay |
| "Total Owed" / "Total owed:" (debtors_totalOwed, debtors_totalOwedLabel) | 1 / 1 | Tie (metric title vs label) |
| "No submissions yet." / "No submissions yet" | 1 / 1; family "No ... yet." 7, without the stop 6 | Not clear |
| "Batch No" / "Batch No." (sales_colBatchNo) | 2 / 1 | Below the rule (2:1, fewer than 3) |
| "Unlabeled Batch" / "Unlabeled batch" | 1 / 1 | Tie (title vs line) |
| "Note (optional)" / "Notes (optional)" | 1 / 1 (+ "Reference/Note (optional)") | Tie; singular/plural |
| "Out of Stock" / "Out of stock" (alerts, sales; also "- 0 available", "- nothing sellable") | 2 / 2 | Tie |
| "Vet" / "Veterinary" (productGroup_vet, productGroup_veterinary) | 1 / 1 | Tie; chip length |
| Notification categories plural (cards) / singular (table) | 3 / 3 | Different places, on purpose? |
| Case pairs: View All 2 / View all 1; More actions 2 / More Actions 1; This Month / This month, This Year / This year, All Time / All time, Last 7/30 Days / days (export and payments vs services, clients, reports) 5 / 5; Add Facility / Add facility; Delete Account / Delete account; Facility Name / Facility name; Select Method / method; Select Type / type; Service Revenue / revenue; View Batches / batches; Try Again / Try again; Awaiting Review / review; New Debt Today / today; Remove from Facility / facility | each 1 / 1 or 2 / 1 | Below the rule; mostly title vs button vs line. Period values 'Today'/'Last 7 days' are stored filter values: only labels could change |
| "New" / "NEW", "System" / "SYSTEM" | 2 / 1 | Badge and section header styling, on purpose |
| "cannot" / "can't" | 14 / 12 | Not clear |
| "do not" / "don't", "is not" / "isn't", "was not" / "wasn't", "will not" / "won't", "are not" / "aren't" | 1/5, 1/5, 3/1, 1/1, 1/1 | Whole sentences; contractions are style, owner decides one rule |
| Mid-sentence "could not" (activity_retentionNotDeletedDetail, team_signInSwitchFailed) | 2 | One is the owner's own English (E4b2); the other belongs to the next item |
| The two retention failed-delete messages (Activity Log vs Facilities) | 2 wordings | Sentence rewrite |
| "We couldn't reach the server. Check your (internet) connection..." x2 and membership_unreachable | 3 wordings | Sentence rewrite |
| "No facilities found." / "No facilities found for your account." | 1 / 1 | Different meaning |
| team_signInSwitchFailed after a failed reactivation or removal | 1 | Needs new sentences (E4b2) |
| "Within 30 days" (Product Alerts) | number typed | A {days} placeholder is a code change |
| Kiswahili short relative times ("dakika 5 zilizopita") | 3 keys | Language fit, owner |
| Facility name and type order; link sentences in pieces; screen names inside Business Hours and Manage Account sentences | | Structure (placeholders, code) |
| "Payment Details" one key for two places | 1 | Kiswahili fits both |
| The picker footer "•" (2F-11) | | Already decided; kept |
| Debt reminder to customers | | English, outside the ARB (E5) |
| ERASE, DEACTIVATE, typed facility name; receipts, exports, legal, stored text | | Never changed here |
