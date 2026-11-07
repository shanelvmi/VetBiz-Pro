# PH8b design: Facilities on phones

Batch PH8b (RUNBOOK2 ledger), part (2). `lib/screens/facilities/facility_screen.dart` (about 2,960 lines, admins, reached from More and the profile drawer) on the PH5a pattern (`phone_list_pattern.md` R1 to R12) and the PH6 form shell (`phone_foundations.md` S4, S6). Line numbers are at `41bc934`. Phones only (`AppLayout.isPhone`): `build` asks once; tablets and computers keep today's screen, proved by the 48 `ph8b-facilities-` wide fingerprints recorded before any change (`007cc67`). The facility name is shown alone everywhere (`FacilityDisplay.name`), the type only as the small `FacilityTypeTag`; colours are `context.colors` roles, sizes named constants, texts ARB keys (new Kiswahili draft).

## Today (all widths below 900 stack the two panels)

- **List panel** `_buildListPanel` (:1432): a search field (name or code), three status chips (All, Active, Inactive: `_listStatusFilter`, stored keys), rows `_buildFacilityListRow` (:1534: a 40 px logo box, the name, the type tag, the address, the status chip). Below 900 it is a 360 px high box (`_listPanelHeight`, :1400) above the details; from 900 a 340 px column (`_listPanelWidth`, :1414).
- **Details** `_buildDetailPanelContent` (:1606): a breadcrumb with More Actions (Edit, Switch to this, Delete; :1623), the header card (:1680: logo, name, type, code with Copy, contacts, licence with Copy), the metrics row (:1923), and six tabs in a sideways scroller (`_buildTabsRow`, :2052): Overview (:2833), Team Members (a link to Team Members), Inventory Summary (:2151), Sales Summary (:2314), Activity Log (:2429), Settings (:2449: Edit details, Deactivate or Reactivate, Delete, the log retention and the debt overdue threshold).
- **Nine dialogs:** the facility limit (:400), Add (:426), Edit (:662), Delete blocked by assistants (:1123), Delete's typed confirmation (:1160, the facility name typed exactly), the status toggle (:2618), the retention picker (:2667) and its "delete older logs now?" confirmation (:2699), the overdue picker (:2760).
- The app bar has Refresh and Add Facility; Add is guarded by the platform's facility limit (`loadMaxFacilitiesPerAdmin`, :398) and the server.

## Phone layout

**P1 The list (PH8b-1).** `PhoneListScaffold`, pushed (back arrow, title only, R1): search in the bar (today's name-or-code match), the three status chips as `PhoneQuickChips` (the same `_listStatusFilter`), no Filter button (there is no other filter), no summary line (there are no cards). Rows (`RecordTile`, R6): a 40 px leading with the logo (contained, on `surfaceMuted`) or the name's initials; line 1 the NAME ALONE; line 2 the type as the small `FacilityTypeTag` and the status chip (text and colour); the row is read aloud as its name, type, status and code. No buttons. Add Facility floats (R2) and calls today's `_showAddFacilityDialog` (the limit check first). Pull to refresh is today's Refresh (`fetchFacilities`); six skeleton rows while loading; today's texts for none found and no match. The 340 and 360 panels do not exist on a phone: the list is the page.

**P2 The details page (PH8b-2).** A tap opens a full page (R7): the app bar shows the name alone and one overflow menu with today's More Actions (Edit, Switch to this when it is not the open one, Delete). The body, one column: the header card (the code and licence with their Copy buttons unchanged), the metrics as two columns, then the six tabs as a list of rows (icon, label, the Team Members count) instead of the sideways scroller: Overview is shown inline under the metrics; each other row pushes its tab's content as its own page (the same builders), so nothing scrolls sideways. Labels under 12 px become 12 (S3).

**P3 Add and Edit (PH8b-2).** The PH6 form shell as a full page (`showAdaptiveForm` on phones; tablets keep the dialog): one column, 48 px fields, `FormActionBar` (Cancel, Save) pinned and lifted over the keyboard, `PhoneDiscardScope` asking before a typed form is left. The fields, their order, `FacilityTypeField` with its Other text and errors, and the validators are today's. The logo: the shared photo picking path with today's `UploadSizeCheck` (too large is refused with today's message) and today's png at `facility_logos/{id}.png`; Remove logo as built.

**P4 The dialogs (PH8b-2).** On a phone each through `showSheetOrDialog` (title, scrolling body, actions pinned side by side, lifted over the keyboard): the limit (OK), Delete blocked (OK), Delete's typed confirmation (not dismissible; the field and the compared word unchanged, the button enabled only on an exact match), the status toggle, the retention picker and the overdue picker (the same radio rows, Cancel pinned), the retention confirmation. Their texts, results and saves are today's. Tablets and computers keep today's `showDialog`s.

**Unchanged everywhere:** who sees the screen (admins), the queries and their counts, the facility code and invite parts, the Team Members link, the delete callable and what follows it, ERASE and DEACTIVATE style typed words (English).

## Saves (proved equal)

Before changing Add or Edit, a test records from today's code, for fixed inputs (a name, each type with Other's words, contacts, ownership, status, restock frequency, a logo), what Add sends (`MembershipService.addFacility`'s arguments, then the facility document's writes and the upload's path, size and content type) and what Edit writes (the facility document, the logo upload or delete, `syncFacilityDetails`); the phone form must produce the same (`test/fixtures/ph8b_saved_facility.json`).

## Tests (written first, committed skipped)

The chips and search equal the wide list's on the same fake data; rows: the name alone, the type only as the tag, a 40 px leading, no buttons; the FAB and its limit guard; pull to refresh; the states; the details page's actions equal today's More Actions and Settings rows; no horizontal scroller on a phone; each dialog a sheet on a phone (and the wide fingerprints for the old dialogs); the typed delete confirmation; the discard check and the keyboard-lifted bar; the saved facility equals the old one; the matrix at 360x740, 390x844 and 740x360 in Light, Dark and Kiswahili with a very long facility name.

## Rollout and rollback

Phones only; each part is a phone branch in `build` or in one dialog helper, so a rollback is a revert of its commits. Nothing stored changes.
