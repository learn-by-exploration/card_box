# V-Model Development Plan

## Purpose

Use the V-model to keep the app honest: user needs and system requirements on
the left side, implementation at the bottom, and explicit verification on the
right side.

## V-Model Stages

| Left side artifact | Development activity | Right side verification |
| --- | --- | --- |
| User needs | Stakeholder interviews, app-store/GitHub research | User acceptance tests |
| Concept of operations | Define actors, modes, scenarios, constraints | Operational scenario validation |
| Operational workflows | Define end-to-end user flows and edge cases | Workflow acceptance tests |
| System requirements | Functional, safety, privacy, platform constraints | System tests |
| Architecture | Flutter app, storage, scanner, security design | Integration tests |
| Module design | Card model, vault, scanner, search, import/export | Unit/widget tests |
| Implementation | Flutter code and platform configuration | Static analysis, tests, builds |

## Initial Milestones

1. Requirements baseline
   - Define target card types.
   - Separate "store and present" features from "read/write/emulate" features.
   - Capture Android/iOS limits early.
2. Feasibility prototype
   - Flutter app shell.
   - Local encrypted card database.
   - Camera import for card photos and barcode/QR.
   - NFC tag read experiment on Android and iOS.
3. MVP
   - Add, edit, search, group, and archive cards.
   - Store front/back images.
   - Store barcode/QR payloads.
   - Store NFC metadata when readable.
   - Export/backup data safely.
4. Validation
   - Test with real card categories.
   - Verify privacy behavior.
   - Publish as free/open-source app if the MVP is useful and safe.

## Working Assumptions

- We will use Flutter because `board_box` already uses it across Android and
  iOS.
- The first release should be offline-first and should not require a paid cloud
  service.
- Any NFC/RFID functionality must be described by capability, not wishful
  product language.
