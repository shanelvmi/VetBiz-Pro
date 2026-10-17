# FIXES (corrections found in review; do these FIRST, one commit each)

Source: the owner's decisions after the audit of batches 2F-6 to 2F-12.
Status of this file: OPEN
(Earlier items from batches 2F-6 and 2F-7 are DONE; this file replaces that list.)

## 1. Login password message: stop quoting a wrong minimum

The login screen says "Minimum 6 characters" while registration requires 8. The owner wants 8 as the minimum. **Do NOT make the login form enforce 8 by default**: Firebase's own password-reset page accepts 6-character passwords, and older accounts may have shorter ones, so enforcing 8 at login could stop someone from even attempting to sign in.

Do this instead:
- The login form checks only that an email and a password were entered. Remove the length check from login.
- Change the login validation message in both languages to say, in English, "Enter your email and password." Keep its key, update `app_en.arb` and the Kiswahili draft (mark it `draft`), run the export tool, and commit the CSV and snapshot.
- Registration keeps its 8-character rule. Make sure the registration message states "at least 8 characters" in both languages (it may already; if so change nothing).
- **OWNER OPTION, OFF unless this line is edited to say ENFORCE-8-AT-LOGIN:** enforce 8 characters at login.

## 2. Read-only report: every place a password is set

Do NOT change anything. Search the app and list, in the ledger row for this fix, every place where a user can set or change a password (registration, any change-password dialog in Manage Account or Settings, and anything that calls `updatePassword`, `confirmPasswordReset`, or creates a user with a password), and the minimum length each one checks. Also note that the password-reset email link opens Firebase's own page, which the app does not control. The owner will decide from this whether login can ever enforce 8.

## 3. "1 day" and "Over 1 day" (APPROVED by the owner)

In Active Debts the English reads "1 days" and "Over 1 days". Make them "1 day" and "Over 1 day" using ICU plural keys, in both languages:
- Find the keys that show a number of days in the Active Debts screen (for example `debtors_daysCount` and the "Over N days" key). Other screens reuse `debtors_daysCount` (for example the activity log retention dialog); they get the same fix, which is intended.
- English: `{count, plural, =1{1 day} other{{count} days}}` and the "Over" equivalent.
- Kiswahili: use the correct singular and plural forms (Swahili "siku" does not change with the number, so both branches may read the same; keep the draft marking).
- Add a test: the label for 1 reads "1 day" and for 0, 2 and 30 reads "N days"; the same for "Over".
- Do NOT touch the other "1 payments", "1 debts", "of 1 products", "1 units", "1 found" slips; list them for the owner in `docs/design-open-questions.md` if they are not already there.

## Done criteria

Analyze with no new infos, "All tests passed", the guard baseline lowered or unchanged, no push. Mark this file `ALL DONE` and list the commits when finished.
