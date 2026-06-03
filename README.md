# Card Box

Card Box is a proposed free, open-source mobile app for organizing the cards
people carry every day: RFID/NFC cards, loyalty cards, membership cards, ID
cards, access cards, gift cards, and barcode/QR based passes.

This workspace is starting with requirements and system engineering artifacts
before implementation. The intended development model is V-model: each
requirement should eventually map to architecture, implementation, and a
verification method.

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

## Documents

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
- [Research notes](docs/research/initial_research.md)
- [Open questions](docs/v_model/open_questions.md)
