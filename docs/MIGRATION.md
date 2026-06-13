# Card Box — Migrations

This document covers the two on-device migrations Card Box has
shipped: the legacy `shared_preferences` → SQLite move (v0 → v1)
and the in-SQLite schema upgrade (v1 → v2).

## v0 → v1 — Move cards out of `shared_preferences`

In the very first build of Card Box, the entire card library was
JSON-encoded and stored under a single
`shared_preferences` key (`card_box.cards.v1`). That worked for
a handful of cards but quickly ran into the 1 MB-ish preference
limit and made per-card queries (search, archive, filter) require
a full load and re-scan.

In v1, the same JSON was loaded once on first launch, inserted
into a `card_records` table in a SQLite database, and the legacy
key was removed. The migration is run by
`CardRepository._migrateLegacyStorageIfNeeded` and is guarded by
the absence of the new table: if `_database.loadCards()` returns
an empty list, the legacy preference is read once and bulk-loaded
into the database. The source-of-truth then flips from
`shared_preferences` to SQLite; subsequent launches go straight to
the database and never read the legacy key again.

The migration is atomic with respect to a single user
(`shared_preferences` is user-scoped) but is not transactional
with the database — the bulk insert is wrapped in
`replaceAllCards` so the table is either fully populated or
empty, and the legacy key is removed only after the bulk insert
returns successfully.

### Rollback

There is no automatic rollback. If the user downgrades the app
past v1, the new code path is not exercised and the database
file is simply ignored. The next v0 launch will read the legacy
`shared_preferences` key and re-build the in-memory library from
it; nothing is lost. Upgrading again will re-run the migration.

## v1 → v2 — Add normalized columns to the `card_records` table

In v2, Card Box started supporting per-card search, archive
filtering, and category-based sort. To make those features
O(1)-ish without scanning the payload JSON for every card, the
schema gained the following columns on `card_records`:

- `name_text` (TEXT) — the human-readable name
- `issuer_text` (TEXT) — the issuing organization
- `category_name` (TEXT) — the `CardCategory` enum name
- `custom_category_text` (TEXT, nullable) — the free-form label
  when `category_name = 'other'`
- `card_type_name` (TEXT) — the `CardType` enum name
- `compatibility_status_name` (TEXT) — the `CompatibilityStatus`
  enum name
- `search_text` (TEXT) — a precomputed lowercased concatenation
  of every text field that participates in card search

The migration is run by `CardDatabase.migration.onUpgrade` and
has two phases:

1. `addColumn` for each of the new columns. The Drift migrator
   does this in a single transaction so a partial column set
   cannot be observed.
2. `_backfillNormalizedColumns` walks every existing row,
   re-derives the values from `payload_json`, and writes the
   new columns. Each row is wrapped in its own try/catch so a
   single corrupt row does not abort the upgrade; the row's
   `payload_json` is unchanged and will be skipped on read by
   the same per-row try/catch in `loadCards`.

### Reading post-migration

The drift query for cards (`select(cardRecords).get()`) returns
the same `CardRecord` shape regardless of schema version. The
codec layer is the only code that knows about the historical
shape; it reads `payload_json` and rebuilds the `WalletCard`
domain object. Normalized columns are used only by the search
and filter paths, never as the source of truth for rendering.

### Rollback

There is no automatic rollback. The new columns are populated
by `_backfillNormalizedColumns`, but on a downgrade the new code
path stops running. The new columns become inert extra data in
the SQLite file. No data is lost.
