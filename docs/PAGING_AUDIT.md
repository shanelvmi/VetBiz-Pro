# Paging audit (UX4, 2026-11-22)

Read-only. No screen was changed for this audit. PC and tablet unless the row
says otherwise. "Pager" means the shared `ListPageBar` (range, page size
10/25/50, previous / page / next). "Own pager" means a footer written in the
screen with the same idea. Costs are Firestore document reads; memory is the
rows the app keeps.

## Summary

| Screen | Load | Display (PC/tablet) | Verdict |
|---|---|---|---|
| Sales | cursor get, 25/page, newest 25 live (`CursorPaginatedListController`) | ListPageBar | ok |
| Services | cursor get, 25/page, newest 25 live | ListPageBar | ok |
| Clients | cursor get, 25/page; **plus the whole `clients` collection streamed live** (`listenToClients`, also started by `facility_activation`) | ListPageBar | unbounded read (scalability risk) |
| Debtors | cursor get, 25/page (`debtorsListController`); rides the same whole-clients stream for lookups | ListPageBar | ok (risk shared with Clients) |
| Payments | one get per date range of `payments` + other-income `transactions`, **no limit**; a name search ignores the date range | all rows (ListView) | unbounded read (scalability risk) |
| Transactions | newest 25 live, then "Load more" 25 at a time, kept in memory; type filter and search run only on loaded rows | all loaded rows + Load more button | add pager |
| Products | **whole `products` collection streamed live** (`ProductProvider`), paged in memory (`ProductCatalogService`, 12) | own numbered pager, 12 fixed | unbounded read (scalability risk); add pager (ListPageBar) |
| Stock Store | same products stream, paged in memory (12) | own numbered pager, 12 fixed | unbounded read (scalability risk); add pager |
| Stock Alerts | computed from the same products stream | ListPageBar (UX1b) | ok (risk is the products stream) |
| Sales archive | cursor get, 30/page, appended | ListPageBar over loaded rows (10/25/50); next page fetches | ok |
| Services archive | cursor get, 30/page, appended | ListPageBar over loaded rows | ok |
| Activity Log | stream, `limit(500)` (`ledgerQueryCap`); assistants: two merged streams of 500 | all rows (ListView), no pager | add pager |
| Notifications | stream of newest 200, "Load older" 100 at a time | own pager (10/25/50) + Load older | add pager (swap to ListPageBar) |
| Trash | stream of the whole trash collection, no limit | all rows (ListView) | unbounded read (scalability risk) |
| Team Members | gets of the facility's members | own pager (10/25/50) | ok (bounded) |
| Facilities | the person's facilities; **each card reads all its clients and all its products** for its figures | cards, no pager | ok as a list; card figures are an unbounded read (scalability risk) |
| Past Reports | cursor get, 25/page | all loaded + Load more button | ok (bounded by use); add pager optional |
| Subscription history | stream, `limit(200)` | own pager (10/25/50) | ok |
| Subscription page (recent) | stream, `limit(5)` | 5 rows + View all | ok |
| Export | one get per collection and date range at export time, no limit; products export reads every batch | not a list (a file) | ok as a one-off; large ranges are heavy |
| Platform Admin: Facilities directory | cursor get, 50/page, infinite scroll | list | ok (operator only) |
| Platform Admin: Users | cursor get, 50/page, infinite scroll | list | ok |
| Platform Admin: Subscription requests | stream of pending (no limit); reviewed since a date | list | ok (small) |
| Platform Admin: Platform admins | stream of all admins | list | ok (tiny) |
| Platform Admin: Announcements | stream ordered by time | list | ok (tiny) |
| Platform Admin: Overview | **get of every facility** + collection-group queries | figures | unbounded read (scalability risk) at platform scale |

## Worst cases (5,000 / 50,000 records)

- **Cursor lists (Sales, Services, Clients list, Debtors, archives, Past
  Reports):** 25 (or 30) reads per page and per new page, plus one `count()`
  for "N new". Memory: the pages visited. Fine at 50,000.
- **Clients (whole-collection stream):** 5,000 / 50,000 reads every time the
  facility activates, plus one read per changed client while open; all held in
  memory. At 50,000 this is slow to start and costly. The paged list is already
  in place; the full stream is kept for lookups (Debtors, search fallback).
- **Products / Stock Store / Stock Alerts:** same pattern as Clients on
  `products`. Catalogues rarely pass a few thousand, so lower risk, but the
  service was written to swap to real queries (its own comment).
- **Payments:** a wide date range (a year) at a busy facility reads every
  payment in it at once and draws every row; a name search reads every match
  for all time.
- **Transactions:** each "Load more" keeps adding 25 rows in memory; filters
  and search only see what is loaded, so a match on an unloaded page is missed.
- **Activity Log:** capped at 500 reads (1,000 for an assistant's two
  streams), drawn as one list; older entries are unreachable.
- **Trash:** every trashed item, live; grows until emptied.
- **Facilities:** one full read of clients and products per facility card, on
  every open. An owner with 3 facilities of 5,000 clients reads 15,000+ docs.
- **Notifications:** 200 live + 100 per Load older; bounded per step.

## Recommended rule

**Every list on PC/tablet that can grow without limit uses `ListPageBar` with
server-side paging (`CursorPaginatedListController`: a bounded cursor read per
page, page size 10/25/50). Card grids (Products, Stock Store) use the same
`ListPageBar`. Bounded lists (Team Members, Facilities, Past Reports,
Subscription history, the Platform Admin tabs) need no pager. The phone keeps
its infinite scroll (`PhoneListScaffold`, `onLoadMore`) over the same
controller.**

Order of work this suggests (owner to decide; none started):

1. Transactions: move the wide table onto `transactionsListController` (it
   exists) and `ListPageBar`; filters become part of the query.
2. Activity Log: cursor pages with `ListPageBar` instead of one 500-row list.
3. Notifications and Team/Subscription history: swap their own footers for
   `ListPageBar` (same behaviour, one widget).
4. Products / Stock Store: `ListPageBar` instead of the numbered pager (UI
   only; the data stays in memory for now).
5. Scalability, separately: Payments date range cap or cursor; Trash limit +
   pager; Facilities card figures from the daily summaries or `count()`
   instead of full reads; the whole-collection Clients and Products streams
   (largest change, needs a design of its own).
