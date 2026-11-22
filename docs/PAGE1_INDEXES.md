# PAGE1: composite indexes needed (not deployed)

PAGE1 did not edit `firestore.indexes.json`. Every query PAGE1 runs uses an
index that already exists, except the one filter below, which is **off** on
PC/tablet until these are deployed. Owner deploys (`firebase deploy --only
firestore:indexes`), then the filter can be turned back on as a server query.

## Activity Log: category filter (and its counts)

The chips filtered and counted from an unbounded stream of the whole
retention window. As server queries (one page, plus a `count()` per category
for the chip numbers), they need:

| Collection | Scope | Fields | For |
|---|---|---|---|
| `activity_logs` | COLLECTION | `actionType` ASC, `timestamp` DESC | admin: a category, newest first, inside the window |
| `activity_logs` | COLLECTION | `userId` ASC, `actionType` ASC, `timestamp` DESC | assistant: their own entries of a category |
| `activity_logs` | COLLECTION | `targetUserId` ASC, `actionType` ASC, `timestamp` DESC | assistant: entries about them of a category |

JSON for `firestore.indexes.json` (`indexes` array):

```json
{ "collectionGroup": "activity_logs", "queryScope": "COLLECTION", "fields": [
  { "fieldPath": "actionType", "order": "ASCENDING" },
  { "fieldPath": "timestamp", "order": "DESCENDING" } ] },
{ "collectionGroup": "activity_logs", "queryScope": "COLLECTION", "fields": [
  { "fieldPath": "userId", "order": "ASCENDING" },
  { "fieldPath": "actionType", "order": "ASCENDING" },
  { "fieldPath": "timestamp", "order": "DESCENDING" } ] },
{ "collectionGroup": "activity_logs", "queryScope": "COLLECTION", "fields": [
  { "fieldPath": "targetUserId", "order": "ASCENDING" },
  { "fieldPath": "actionType", "order": "ASCENDING" },
  { "fieldPath": "timestamp", "order": "DESCENDING" } ] }
```

Note: old sale entries are stored as `Sale` and shown under `Sales`
(`ActivityType.canonicalKey`); the Sales filter would query
`actionType whereIn ['Sales', 'Sale']`, which these same indexes serve.

## Checked, already indexed (no action)

- Transactions: `type` + `date` desc (+ `__name__`), `type` + `descriptionLower`.
- Payments: `source` / `paymentMethod` / `clientId` + `timestamp` desc;
  `source` / `paymentMethod` + `clientNameLower`; other income `type` + `date`,
  `type` + `paymentMethod` + `date`. The range totals are `sum`/`count`
  aggregates over the same queries.
- Activity Log pages: `timestamp` (single field); assistant `userId` /
  `targetUserId` + `timestamp` desc.
- Notifications: `createdAt` (single field).
- Trash: `deletedAt` (single field); the soon-to-expire count is a `count()`
  over a `deletedAt` range.
