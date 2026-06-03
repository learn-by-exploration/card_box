# Traceability Matrix

Status: draft, created 2026-06-03.

| Need / Decision | Requirement IDs | Design Area | Verification |
| --- | --- | --- | --- |
| Organize many physical cards | SYS-001, SYS-006 | Card catalog, local database | Widget tests, storage tests |
| Include front/back photos | SYS-002 | Card media | Manual/integration tests |
| Support barcode and QR cards | SYS-003 | Barcode wallet | Unit/widget tests, camera test |
| Support NFC where platforms allow | SYS-004, SYS-005, SYS-014 | NFC reader, capability classifier | Android device test, iOS later test |
| Avoid false emulation promises | SYS-005, SYS-009, SYS-014 | Capability classifier, UX copy | Requirements review, manual tests |
| Exclude credit/debit cards | SYS-009, SYS-011 | Product policy, validation copy | Requirements/code review |
| Offline-first with user export | SYS-006, SYS-007, SYS-010 | Storage, export/import | Storage, export, network behavior tests |
| Android-first prototype, iOS later | SYS-008, SYS-013 | Platform services | Android build/device tests, iOS build check |
| Future app lock | SYS-012 | Security architecture | Architecture review |
| Permission-first interfaces | SYS-015 | Platform services, UX flow | Manual/platform permission tests |
| Plain JSON prototype export | SYS-010, SYS-016 | Export/import | Export round-trip test |
| Extensible card categories | SYS-001, SYS-017 | Card catalog | Unit/widget test |
| Support visiting-card digitization | SYS-018, SYS-019, SYS-020, SYS-021, SYS-022 | OCR pipeline, visiting-card review UI, structured data model | OCR/manual workflow tests |

## Workflow Traceability

| Workflow | Requirement IDs | Verification |
| --- | --- | --- |
| WF-001 Add a new card | SYS-001, SYS-002, SYS-003, SYS-004, SYS-014 | End-to-end add-card test |
| WF-002 Use barcode/QR card | SYS-003 | Presentation-mode widget/manual test |
| WF-003 Test RFID/NFC compatibility | SYS-004, SYS-005, SYS-014 | Android device integration test |
| WF-004 Present reference-only card | SYS-001, SYS-002, SYS-005 | Manual acceptance test |
| WF-005 Export backup | SYS-010 | Export integration test |
| WF-006 Import backup | SYS-010 | Import integration test |
| WF-007 Future app lock | SYS-012 | Architecture review, later security test |
| WF-008 Scan and save a visiting card | SYS-018, SYS-019, SYS-020, SYS-021, SYS-022 | Visiting-card end-to-end test |
| WF-009 Re-extract visiting card details | SYS-019, SYS-020, SYS-021, SYS-022 | Visiting-card regression/manual test |
