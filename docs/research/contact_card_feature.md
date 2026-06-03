# Visiting Card / Contact Card Feature Research

Status: draft, created 2026-06-03.

## Goal

Evaluate whether Card Box should support scanning visiting cards / business
cards and turning them into structured contact records with a human-review flow.

## User Problem

Users receive physical visiting cards and later need to:

- save the person quickly
- avoid retyping names, phones, emails, and addresses
- keep the original card image
- review extracted details before trusting them
- optionally export or share the result as a contact later

This fits Card Box because the app already:

- captures card images
- stores card metadata locally
- supports permission-gated camera flows
- aims to reduce physical-card clutter

## Research Summary

### Official / Primary Technical References

- Google ML Kit Text Recognition v2 supports on-device OCR on Android and
  multiple script packs including Japanese:
  https://developers.google.com/ml-kit/vision/text-recognition/v2/android
- Google ML Kit Entity Extraction on Android can identify structured entities
  from text such as addresses, phone numbers, and URLs:
  https://developers.google.com/ml-kit/language/entity-extraction/android
- Google ML Kit Document Scanner on Android provides native document scan UX:
  https://developers.google.com/ml-kit/vision/doc-scanner/android
- Apple VisionKit supports document scanning and text structuring workflows:
  https://developer.apple.com/documentation/visionkit
- Apple specifically documents structuring recognized text on things like
  business cards and receipts:
  https://developer.apple.com/documentation/visionkit/structuring_recognized_text_on_a_document

### Flutter Packages / Building Blocks

- `google_mlkit_text_recognition` is current, mature, and widely used in
  Flutter:
  https://pub.dev/packages/google_mlkit_text_recognition
- `edge_detection_scan` gives us cleaner card images before OCR:
  https://pub.dev/packages/edge_detection_scan
- `business_card_scanner` is a Flutter package that already does offline OCR
  plus simple field extraction, but its own roadmap admits name/title/company
  extraction is future work:
  https://pub.dev/packages/business_card_scanner

### Open Source Product References

- Meishi is an open-source, privacy-first business card scanner that uses a
  scan -> extract -> review flow:
  https://meishi.dev/
- OSS CardWallet shows a broader card-wallet direction with OCR and card
  storage, though it is not specifically focused on contact extraction:
  https://ossdocumentscanner.akylas.fr/cardwallet/getting-started

## What The Research Suggests

### 1. OCR is easy compared to field extraction

Reading raw text from a visiting card is feasible today with on-device OCR.

The hard part is turning that text into the right fields:

- person name
- company
- role / title
- phone numbers
- email
- website
- address
- social handles

That difficulty gets worse with:

- mixed layouts
- two-language cards
- vertical Japanese text
- logos that resemble text
- multiple phone numbers
- multiple people on one card
- cards with very little whitespace

### 2. Human review is not optional

For visiting cards, a fully automatic "scan and save perfectly" promise would be
unreliable.

The better product shape is:

1. user scans card
2. app extracts candidate fields
3. app shows the card image and suggested fields side by side
4. user accepts, edits, or ignores each field
5. app saves the card as a contact-style record

This is a much safer UX than silent auto-fill.

### 3. On-device privacy-first is realistic

A strong first version can stay local-first:

- edge/document scanning for the image
- on-device OCR
- deterministic parsing plus heuristics
- manual review

We do not need cloud OCR to create a useful first release.

### 4. Advanced extraction can come later

If we later want better extraction for:

- Japanese meishi
- multilingual layouts
- unusual typography
- role/company disambiguation

then an optional AI-assisted extraction path could help, but it should be:

- user-initiated
- clearly labeled
- not required for the basic feature
- not enabled by default in the privacy-first baseline

## Proposed CONOPS

### Mission

Help users convert physical visiting cards into usable contact records while
keeping the original card image and preserving user review before save.

### Actors

| Actor | Role |
| --- | --- |
| Primary user | Scans the visiting card and confirms extracted details |
| Physical visiting card | Source of image and text |
| Phone platform | Provides camera, local OCR, storage, and optional contact export |
| External contact app | Optional destination for vCard/contact sharing later |

### Operational Modes

| Mode | Description |
| --- | --- |
| Scan mode | Capture a cleaner image of the visiting card |
| Extract mode | Run OCR and parse candidate fields |
| Review mode | User accepts or edits extracted values field by field |
| Save mode | Store the result as a visiting-card record inside Card Box |
| Export mode | Optionally export/share the result later as contact data |

### Normal Scenario

1. User taps `Add card`.
2. User chooses `Visiting card`.
3. App opens the card scan flow.
4. App stores front image, and optionally back image.
5. App offers `Extract details`.
6. OCR reads text from the image.
7. Parser proposes fields such as name, company, title, phone, email, website,
   and address.
8. User reviews suggestions field by field.
9. User saves the card.
10. App stores:
    - original image(s)
    - raw OCR text
    - accepted structured fields
11. Later, user can:
    - search the person
    - copy a phone/email quickly
    - call or email
    - export/share as a contact

### Failure / Edge Scenarios

- OCR finds text but cannot confidently classify it.
- OCR finds multiple phone numbers or emails.
- Card is bilingual and fields appear duplicated.
- Card contains Japanese vertical text.
- Card back side contains important details.
- User wants only image storage, not extraction.

In all of these cases, the system should degrade gracefully to "image + raw OCR
text + manual edits."

## Feasibility Assessment

### Product Feasibility: High

This is a strong fit for Card Box because it solves a real, adjacent problem and
uses the same capture/storage patterns already in the app.

### Technical Feasibility: Medium-High

A useful v1 is very feasible if we define it correctly.

### Feasible v1

- add `Visiting card` as a card subtype or preset
- scan front image with edge detection
- optional back image
- run on-device OCR
- parse easy fields reliably:
  - email
  - website
  - phone numbers
  - address-like blocks
- infer likely name/company/title heuristically
- show field-by-field review
- store raw OCR text

### Feasible v1.5

- copy buttons for email/phone/address
- `Create vCard` export
- `Add to contacts` handoff
- back-side OCR merge
- multi-language OCR selection where supported

### Feasible v2

- confidence scoring
- smart merging of duplicate numbers/addresses
- optional AI-assisted extraction for difficult layouts
- contact deduplication
- bulk scan for event/trade-show use

## Recommended Architecture

### Keep It Inside Card Box

Do not build this as a separate app feature silo.

Instead:

- add a new `Visiting card` preset
- reuse the same image pipeline
- add a structured `contactFields` model
- add a review screen for extracted data

### Suggested Extraction Pipeline

1. Acquire image:
   - `edge_detection_scan`
   - fallback camera/gallery
2. OCR:
   - `google_mlkit_text_recognition`
3. Deterministic parsing:
   - email regex
   - phone normalization/parsing
   - URL detection
   - address block heuristics
4. Heuristic classification:
   - likely name
   - likely company
   - likely title
5. User review:
   - accept/edit/remove each field

This minimizes risk while still making life easier.

## Open Source Reuse Direction

### Strong candidates to learn from

- Meishi:
  learn from its privacy-first scan -> extract -> review product shape
- `google_mlkit_text_recognition`:
  likely best OCR base for Flutter
- `business_card_scanner`:
  useful reference for simple offline extraction and field modeling

### What not to copy blindly

- packages that promise "business card scanning" but only use regex on raw OCR
  without strong review UX
- cloud-first apps whose accuracy comes from server-side models
- products optimized for CRM lead capture rather than private local storage

## Risks

| Risk | Why it matters | Mitigation |
| --- | --- | --- |
| Incorrect name/company/title extraction | Most user-visible failure | Review screen, keep raw OCR text visible |
| Weak support for multilingual cards | Common in real use | Start with OCR-supported scripts, keep manual edit easy |
| Japanese meishi layouts | Important user case | Test against Japanese samples early; do not overpromise |
| User trusts bad auto-fill | Can create junk contacts | Require review before save |
| Contacts export complexity | Platform-specific | Start with in-app storage first, export later |

## Recommendation

This feature is worth adding.

Recommended decision:

- **Yes** to visiting-card support in Card Box
- **Yes** to scan -> extract -> review -> save
- **Yes** to on-device OCR first
- **No** to fully automatic silent contact creation in v1
- **No** to cloud dependence in the first version

## Suggested Requirement Additions

- The app shall support a `Visiting card` preset.
- The app shall support OCR extraction from visiting-card images.
- The app shall preserve raw OCR text alongside user-approved structured fields.
- The app shall require user review before final save of extracted visiting-card
  fields.
- The app shall support future contact export without requiring cloud hosting.

