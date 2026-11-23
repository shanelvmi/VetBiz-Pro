# PAGE2: Clients search, what ships and the proposed next step

Status: **proposal, not built.** The owner decides. PAGE2 adds no stored field,
no migration and no backfill.

## What PAGE2 ships (owner decision, 2026-11-23)

Server-side prefix search on the fields every client save already writes:

| Typed | Query (PC/tablet Clients) | Finds |
|---|---|---|
| letters (anything not phone-like) | `nameLower >= q` and `< q + ''`, ordered by `nameLower` | names that **start** with the text, any case |
| digits, spaces, `+`, `-` | `phoneKey >= p` and `< p + ''`, ordered by `phoneKey`; `p` drops a leading `00`, `255` or `0` (`clientPhoneSearchPrefix`) | numbers that start with the typed digits, however they were typed when saved |

Both keep the type and status filters, page by `pageSize + 1`, and are
debounced (300 ms) and stale-safe.

**What it cannot find:**

1. **Clients saved before `nameLower` / `phoneKey` existed**, until the
   backfill runs once per facility (`ClientProvider.rebuildSearchIndex`).
   They still show in the A to Z list (it is ordered by `name`, which every
   client has). **Found in PAGE2:** the backfill has a dialog
   (`showRebuildSearchIndexDialog`, `lib/screens/settings/rebuild_search_index_dialog.dart`)
   but no screen opens it, so it cannot be run from the app today. Putting it
   in Settings (admin only) is a one-line entry point; left to the owner,
   since this block triggers no backfill.
2. **A word that is not the first** ("Juma" does not find "Amina Juma").
3. **Part of a phone number in the middle** ("345" does not find 0712 345 678).
4. **The address** (the old hint said "name, phone, address"; the new hint
   says "Search by name or phone").

## Proposed next step: word-prefix tokens

One new array field on each client, written with the rest of the client on
every create and update (the same places that write `nameLower` today:
`ClientProvider.addClient`, `updateClient`, and the restore path):

```
searchTokens: [ "amina", "juma", "712345678" ]
```

- every word of the name, lower-cased, accents left as typed, at most 10 words;
- the `phoneKey` (already normalised), so one field answers both;
- not the address (long, rarely searched; can be added later the same way).

Query, one per page (Firestore allows one `array-contains`):

```
clients
  .where('searchTokens', arrayContains: firstTypedWord)   // exact word
  [.where('types', arrayContains: ...)]  -- not allowed with a second array-contains; see below
  [.where('status', isEqualTo: ...)]
  .orderBy('name')
  .limit(pageSize + 1)
```

**Prefix of a word** ("jum" finds "Juma"): store prefixes, not words: for each
word its prefixes from 2 letters up ("ju", "jum", "juma"). A 3-word name of 6
letters each is about 15 tokens, a phone about 8 (prefixes from 3 digits);
around 25 entries, a few hundred bytes a client. That is the usual Firestore
pattern for "starts with any word" without a search service.

**The type filter** is an `array-contains` too, and Firestore allows only one
per query. Options: (a) store `types` also as plain fields (`isFarmer: true`)
and filter with equality; (b) apply the type filter in memory to the search
page only (a short list); (c) drop the type filter while searching (the
current note "Searching by name (across all types)" already says so on the
phone). Recommended: (b), with the page bar's Next still reading from the
server.

**Index:** `searchTokens` CONTAINS, `name` ASC, `__name__` ASC; plus
`searchTokens` CONTAINS, `status` ASC, `name` ASC, `__name__` ASC.

**Read cost:** the same as today, `pageSize + 1` a page, no count. Writes: one
index entry per token per client (Firestore bills writes, not index entries;
storage grows a few hundred bytes a client).

## Migration steps (owner-run, when approved)

1. Ship the code that writes `searchTokens` on every save (and still writes
   `nameLower` / `phoneKey`).
2. Deploy the two indexes; wait for them to build.
3. Give the backfill its Settings entry (see above), extend it (`rebuildSearchIndex`) to write
   `searchTokens` too, and run it once per facility (it already batches 400
   writes at a time). Cost: one read and one write per client, once.
4. Switch the PC/tablet search query to `searchTokens`; keep the `nameLower`
   query as the fallback while a facility's backfill has not run (the
   backfill can stamp the facility document with the date it ran).

## When it would stop being enough

Typo tolerance ("Amnia"), ranking and contains-anywhere need a search service
(Algolia, Typesense, or Firestore's vector/full-text extensions). Not needed
at the scale of one facility's clients with the token design above.
