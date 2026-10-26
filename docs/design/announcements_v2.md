# AN1 design: announcements v2 (text and poster "Updates")

Batch AN1 (RUNBOOK2 ledger). Audit first, then the Storage rule, the limits and validator, the Platform Admin form. The login, dashboard and notifications screens are NOT changed in AN1 (AN2, AN3). Line numbers are at `dc7c92a`.

## 1. Every reader and writer of `public_announcements` today

The collection name is `Collections.publicAnnouncements` (`lib/data/collections.dart:16`). Nothing in `functions/` reads or writes it (searched). Fields used today: `title`, `message`, `urgent`, `hidden`, `timestamp`. Nothing else is written.

| Where | Reads or writes | Query | Fields |
|---|---|---|---|
| `lib/screens/login_screen.dart:439-520` `_buildAnnouncementsScrollable` | reads (signed out) | `orderBy('timestamp', desc)` | `hidden` (drops true), `urgent` (when any is urgent only the urgent ones show), `title` (fallback `login_announcementFallbackTitle`), `timestamp` (NEW badge under 48 h), `message` through `AnnouncementMessage`. Rotates every `AppTimeouts.loginAnnouncementRotate` in a `PageView` with dots |
| `lib/screens/dashboard/dashboard_screen.dart:460-472` `_watchForNewNotifications` | reads | `where('urgent', ==, true)` | `hidden`, `timestamp` (the bell blinks when an urgent one is newer than the last view) |
| `lib/screens/dashboard/notifications_screen.dart:86-89, 1300-1328` `_urgentStream` | reads | `where('urgent', ==, true)` | `hidden`, `title`, `message` (through `AnnouncementMessage`) |
| `lib/widgets/announcement_message.dart:54` `AnnouncementMessage` | reads (shared) | - | `message` (markdown, with the `{color:#hex}` syntax) |
| `lib/screens/platform_admin/announcements_tab.dart:238-443` `_showAnnouncementDialog` | writes | `add` on create, `update` on edit | create: `title`, `message`, `timestamp` (server time), `urgent`, `hidden: false`; edit: `title`, `message`, `urgent` only (`hidden` and `timestamp` untouched) |
| same file `:445-461` | writes | `doc(id).delete()`, `update({'hidden'})`, `update({'urgent'})` | `hidden`, `urgent` |
| same file `:474-610` (the list) | reads | `orderBy('timestamp', desc)` | `title`, `message`, `urgent`, `hidden`, `timestamp` |

Rules: `firestore.rules:551-554`: read for everyone, create, update and delete for a Platform Admin. No key restriction, so the new fields need no rule change (a rules test proves it, section 4).

Storage today: `storage.rules` has `login_poster/{fileName}` and `login_logo/{fileName}` (Platform Admin writes, public read). Nothing in `lib/` or `functions/` uses either path since G1 (`grep -rn "login_poster\|login_logo" lib functions/*.js` finds nothing; `test/g1_auth_look_test.dart:123,129` asserts their absence). They are removed in AN1.

## 2. The document shape (v2)

| Field | Type | Rule | Old documents |
|---|---|---|---|
| `kind` | string | `'text'` or `'poster'` | missing (or unknown) reads as `'text'`, so every existing document keeps working |
| `title` | string | required, 2 to 80 characters (trimmed) | kept |
| `message` | string | text: required, 2 to 400; poster: optional, up to 200 (an empty one is not written) | kept |
| `imageUrl` | string | poster only: the download URL | - |
| `imagePath` | string | poster only: the Storage path, so the file can be deleted | - |
| `imageWidth`, `imageHeight` | int | poster only: the uploaded image's pixels (lets AN2 reserve the space before it loads) | - |
| `audience` | string | `'all'`, `'en'` or `'sw'` (a poster's words are baked into the image) | missing (or unknown) reads as `'all'` |
| `linkUrl`, `linkLabel` | string | optional; the URL through `SocialLink.sanitize` (http or https with a host); the label required when the link is set, 2 to 24 characters | - |
| `urgent`, `hidden` | bool | unchanged | kept |
| `timestamp` | timestamp | server time on create; unchanged on edit (today's behaviour) | kept |

On edit, a field that no longer applies is removed with `FieldValue.delete()` (a poster turned into text loses `imageUrl`, `imagePath`, `imageWidth`, `imageHeight`; a cleared link loses `linkUrl` and `linkLabel`; a poster's emptied message loses `message`). Old documents are never migrated: they have no `kind` or `audience` and read as text for everyone.

**Old values longer than the new limits.** An old title or message may be longer than 80 or 400 characters. The length limits apply only to a value that is new or changed, so an old announcement opens, can be edited elsewhere (Urgent, audience) and saved with its old text unchanged.

## 3. The poster image

- Limits (named in `lib/config/app_limits.dart`): width 1600 (the picker's `maxWidth`), minimum width 1280, ratio 16:9 with a tolerance of 3 percent, at most 1 MB, JPEG, PNG or WebP only. The picker's `imageQuality` is the shared `AppLimits.pickedImageQuality`. Also the five-slide maximum for AN2.
- The validator (`lib/utils/poster_image_check.dart`) is pure: it finds the type from the file's first bytes (not its name: an SVG or GIF renamed `.jpg` is still refused), then decodes the bytes with `decodeImageFromList` for the width and height, and refuses, in this order: a type that is not JPEG, PNG or WebP (SVG and GIF named), more than 1 MB, a width under 1280, a ratio more than 3 percent away from 16:9. Each refusal is one clear English sentence (the console is English, spec 2.8).
- The form shows the picked image in a 16:9 box with an optional safe-zone overlay (the central 90 percent of the width and 85 percent of the height) and the hint "16:9, 1600 x 900 px, JPG or WebP, under 1 MB".

**Storage path, one deviation from the request.** The request names `announcement_posters/{docId}.{ext}`. The file is saved as `announcement_posters/{docId}-{millis}.{ext}` instead: (1) the upload carries `cacheControl: public, max-age=86400`, so a new image at the SAME path could keep showing the old one for a day; (2) with one fixed name, "if the document write fails, delete the uploaded image" would delete the image the old document still points at, and "delete the old file after the new one is saved" would delete the new file. A fresh name per upload makes both rules safe. The Storage rule matches any file name in the folder, so this changes no rule.

## 4. Storage rule (the E4a method: tests in the emulator first, failing on today's rules for the right reason, then the rule)

```
match /announcement_posters/{fileName} {
  allow read: if true;
  allow create, update: if isPlatformAdmin() && isPosterUpload();
  allow delete: if isPlatformAdmin();
}
```

`isPosterUpload()`: `request.resource.contentType` is exactly `image/jpeg`, `image/png` or `image/webp`, and `request.resource.size <= 1024 * 1024`. The `login_poster` and `login_logo` matches are removed. Tests (`firestore_rules_tests/storage.rules.test.js`): a Platform Admin uploads a small JPEG and a WebP; refused: an SVG, a GIF, 1 MB + 1 byte, a signed-in non-admin, a signed-out visitor; anyone reads; only the Platform Admin deletes; the two removed paths are refused. Firestore: a test with the real poster document (admin create and update succeed, a non-admin and a signed-out visitor are refused, public read still works); `firestore.rules` is not changed unless that test fails.

## 5. Save, edit and delete (the order, so nothing points at a missing file)

- **Save a poster:** the document id is made first (`collection.doc()`), the image is uploaded with its real content type and the cache control, THEN the document is written. Upload fails: nothing is written. Document write fails: the uploaded file is deleted.
- **Edit with a new image:** upload the new file, write the document, then delete the old file. If the document write fails, the NEW file is deleted and the old one is untouched. Turning a poster into text deletes its file after the document is saved.
- **Delete:** the document first, then its file; a file that is not there is not an error (the same rule as Remove photo in G2). A file left behind by a failed delete is harmless; a document pointing at a deleted file is not, hence the order.
- A text announcement never touches Storage.

## 6. Files

- `storage.rules`, `firestore_rules_tests/storage.rules.test.js`, `firestore_rules_tests/firestore.rules.test.js` (a test only).
- `lib/config/app_limits.dart` (limits), `lib/data/announcement_fields.dart` (field names, kinds, audiences, the Storage folder), `lib/data/upload_content_types.dart` (poster metadata).
- `lib/utils/poster_image_check.dart` (validator), `lib/services/announcement_service.dart` (the document shape, validation, the Storage seam, save, edit and delete).
- `lib/screens/platform_admin/announcements_tab.dart` (the form). No ARB keys (English-only console). No change to `functions/` or `pubspec.yaml` (`image_picker` and `firebase_storage` are already there).

## 7. Tests (written first)

The validator cases; the document written for text and for poster (fake Firestore and a fake poster store); the cleanup order (upload fails, write fails, edit with a new image, poster to text, delete with a missing file); the link sanitiser (javascript: refused, a bare host gets https://); audience values; an old document without `kind` or `audience` opens as text for everyone.

## 8. Rollout and rollback

Storage rules are deployed by the owner (`firebase deploy --only storage`) after backing up the live rules text outside the repo; the app can be built before or after (the old app never uploads to `announcement_posters/`). Rollback: `git checkout <previous commit> -- storage.rules` and deploy again. Firestore rules are unchanged.
