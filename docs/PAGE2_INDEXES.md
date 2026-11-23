# PAGE2: composite indexes

All five are in `firestore.indexes.json` (added, **not deployed**). Additive
only: no existing index was removed or changed. Deploy order (CLAUDE.md):
indexes first, then the app.

```
firebase deploy --only firestore:indexes --non-interactive
```

## Two that already exist in the project (were missing from the file)

Copied exactly as `firebase firestore:indexes --project vetbiz-pro` lists them
(2026-11-23). Deploying the file now keeps them instead of offering to delete
them.

| Collection | Scope | Fields | Used by |
|---|---|---|---|
| `clients` | COLLECTION | `types` CONTAINS, `name` ASC, `__name__` ASC (SPARSE_ALL) | PAGE2: the PC/tablet Clients list A to Z with a type filter. Before PAGE2 only by `ClientProvider.listenToClientsPaginated` / `loadMorePagedClients` (nothing calls them now) |
| `payment_submissions` | COLLECTION_GROUP | `status` ASC, `reviewedAt` ASC, `__name__` ASC (SPARSE_ALL) | the operator Overview's "approved this month" (`lib/screens/platform_admin/overview_tab.dart`: `status == approved`, `reviewedAt >=` month start) |

## Three new, for the PC/tablet Clients list

The list is ordered by name (owner decision) and searches on the server:
name prefix on `nameLower`, phone prefix on `phoneKey`
(`ClientProvider._fetchClientsByName`). Every query ends with `__name__` ASC
(the cursor's tie-break).

| Collection | Scope | Fields | Query |
|---|---|---|---|
| `clients` | COLLECTION | `status` ASC, `name` ASC, `__name__` ASC | browse with the Active/Inactive filter |
| `clients` | COLLECTION | `types` CONTAINS, `phoneKey` ASC, `__name__` ASC | phone search with a type filter |
| `clients` | COLLECTION | `status` ASC, `phoneKey` ASC, `__name__` ASC | phone search with the status filter |

Already in the file before PAGE2 and reused: `types` CONTAINS + `nameLower`,
`status` + `nameLower` (name search with a filter). No filter at all needs no
composite index (`name`, `nameLower` or `phoneKey` alone).

**Type and status together** use no index of their own: Firestore merges the
`types` + field and `status` + field indexes for equality filters (the same
the phone's newest-first list has relied on). If Firestore ever answers that
combination with "needs an index", the Clients error view shows the console's
create-index button, and the index to add is `types` CONTAINS, `status` ASC,
then the order field, then `__name__`.

## Until the indexes are built

A query whose index is missing is refused (`failed-precondition`). The PC/tablet
Clients list then shows its error with the create-index button and Retry; the
list without filters and the plain name search keep working (single-field
indexes).

## Reads

Each page reads `pageSize + 1` documents (25 + 1 by default); Previous reads
nothing; no total count. Measured in `test/page2_clients_test.dart`.
