# Card Box

Card Box is a proposed free, open-source mobile app for organizing the cards
people carry every day: RFID/NFC cards, loyalty cards, membership cards, ID
cards, access cards, gift cards, and barcode/QR based passes.

This workspace follows a V-model development path: requirements map to
architecture, implementation, and verification. The app now includes a working
Android-first Flutter prototype plus the system-engineering artifacts that
guided it.

## Current Direction

- Tech stack target: Flutter, following the existing `board_box` project style.
- Primary users: people carrying too many physical cards who want a free,
  privacy-respecting way to organize and retrieve them.
- First product goal: card inventory, notes, photos, barcode/QR storage, NFC tag
  reading where platform APIs allow it, and clear card capability detection.
- Important boundary: the app should not promise universal RFID/NFC cloning or
  emulation. Many cards cannot be copied or emulated by normal phones, and some
  use cases are restricted by platform rules, cryptography, issuer systems, or
  law.

## License

Card Box is released under the [GNU Affero General Public License v3.0 or
later](LICENSE) (AGPL-3.0). The AGPL was chosen because the app stores
sensitive local data and may add a hosted service later; the
source-disclosure clause keeps any network-facing derivative of the code
under the same license.

## Documents

### Engineering practice (synced from board_box)

These docs were authored for board_box and ported here. The file
references in the worked examples are board_box-specific (e.g.
`KlondikeModel`, `GameStats`, iOS `Runner.messenger`); the patterns
and rules are universal Flutter/Dart practice and apply here as-is.

- [Coding guidelines](docs/engineering/coding-guidelines.md)
- [Coding guidelines — models, services, widgets, errors, tests, Dart 3](docs/engineering/coding-guidelines-types.md)
- [V-model lifecycle](docs/engineering/v-model.md)
- [Flutter / Dart style — lint rationale](docs/engineering/flutter-dart-style.md)
- [Testing strategy](docs/engineering/testing-strategy.md)
- [CI/CD](docs/engineering/ci-cd.md)
- [Bug-hunt process](docs/engineering/bug-hunt-process.md)
- [Per-PR code review checklist](docs/engineering/code-review-checklist.md)
- [Secrets & privacy](docs/engineering/secrets-and-privacy.md)
- [UI/UX reference](docs/engineering/ui-ux-reference.md)

### Design process (synced from board_box)

- [01 — Design process](docs/design/01-design-process.md)
- [02 — Architecture](docs/design/02-architecture.md)
- [03 — Design system](docs/design/03-design-system.md)
- [04 — UI/UX principles](docs/design/04-ui-ux-principles.md)
- [05 — Component library](docs/design/05-component-library.md)
- [06 — Feature decomposition](docs/design/06-feature-decomposition.md)
- [07 — PR review checklist](docs/design/07-pr-review-checklist.md)
- [08 — AI assistant guide](docs/design/08-ai-assistant-guide.md)

### V-Model artifacts (card_box-native)

The artifact set for card_box's own V-Model. The V-Model
*lifecycle* doc (linked under "Engineering practice" above) maps the
V to these artifacts and to the design/ tree above.

- [V-model plan](docs/v_model/plan.md)
- [Concept of operations](docs/v_model/conops.md)
- [Operational workflows](docs/v_model/workflows.md)
- [v0.1 requirements baseline](docs/v_model/v0_1_baseline.md)
- [Initial requirements](docs/v_model/requirements.md)
- [Prototype scope](docs/v_model/prototype_scope.md)
- [Architecture options](docs/v_model/architecture_options.md)
- [Decision record](docs/v_model/decision_record.md)
- [Traceability matrix](docs/v_model/traceability_matrix.md)
- [Implementation status](docs/v_model/implementation_status.md)
- [Open questions](docs/v_model/open_questions.md)

### Project-local research and testing

- [Research notes](docs/research/initial_research.md)
- [Android device acceptance](docs/testing/android_device_acceptance.md)
- [Android device validation matrix](docs/testing/android_device_matrix.md)
- [Android test session log](docs/testing/android_test_session_log.md)
- [Android test session runbook - 2026-06-07](docs/testing/android_test_session_2026-06-07.md)
