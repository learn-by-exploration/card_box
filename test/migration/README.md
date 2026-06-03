# Migration Test Notes

This folder documents how Card Box keeps local data migrations understandable
 as schema versions change.

## Why this exists

Card Box stores user data locally and must keep that data readable across app
 updates. Migration tests should be based on realistic historical payloads, not
 only hand-built maps inside test code.

The goals are:

- preserve old user data safely
- make migration intent easy to review
- keep future schema changes from silently breaking photo paths or card fields

## Fixture naming

Migration fixtures live in `test/fixtures/`.

Use names shaped like:

- `legacy_storage_v<version>_<case>.json`
- `legacy_backup_v<version>_<case>.json`

Examples:

- `legacy_storage_v1_file_uri_paths.json`
- `legacy_backup_v1_photo_key_aliases.json`

Meaning:

- `storage` means on-device persisted app data
- `backup` means exported/imported backup payloads
- `v<version>` is the source schema version represented by the fixture
- `<case>` explains the specific migration scenario being covered

## What to include in a fixture

Each fixture should represent one concrete historical shape that we genuinely
 want to keep supporting.

Good examples:

- renamed keys
- missing fields that later became required
- legacy enum values
- `file://` image paths
- old photo field names
- older backup envelopes

Keep fixtures:

- small
- realistic
- focused on one migration concern when possible

## Test expectations

For each fixture, tests should verify:

- the payload decodes successfully
- the decoded cards match the current model shape
- migrated fields land in the correct current keys
- schema version upgrades to the current version
- path normalization happens when expected

If a migration changes media handling, add assertions for both:

- card field values after migration
- attachment/path behavior after import when relevant

## When adding a new schema version

When storage changes in a way that could affect existing users:

1. add a forward migration step in the codec or repository
2. add one or more fixtures representing the old payload shape
3. add tests that decode those fixtures through the real migration path
4. keep old fixtures unless support is intentionally dropped

## Current fixture set

- `legacy_storage_v1_file_uri_paths.json`
  Covers old on-device storage where photo paths were stored with `file://`
  prefixes.

- `legacy_backup_v1_photo_key_aliases.json`
  Covers old backup payloads that used `frontPhotoPath` and `backPhotoPath`
  instead of current image-path field names.
