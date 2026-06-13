# Open Questions

This file tracks questions that affect the v0.1 baseline. Each entry now
records the current resolution (or a "deferred" status with the
reason) so a reader can see at a glance what is still open. See
`decision_record.md` for the full reasoning behind each resolved
question.

## Resolved (2026-06-03)

1. **Which card categories matter most for the first release?**
   - Resolved: support whatever is realistically possible on Android
     and iOS, excluding credit and debit cards. The default set is
     Loyalty, Membership, Access, Transit, Gift, ID, Library, and
     Other; users can rename or extend it.

2. **Is the main pain "too many cards in wallet" or "want the phone to
   act like the card"?**
   - Resolved: both. The MVP organizes cards and presents
     barcode/QR/NFC data where possible; RFID/NFC emulation is a
     later Android-first track (see DR-001).

3. **Should the first MVP avoid card emulation entirely and focus on
   organization, barcode/QR, camera, and NFC reading?**
   - Resolved: yes for v0.1, with emulation as a later Android-first
     capability track (see DR-001).

4. **Do users need encryption/passcode/biometric unlock from day one?**
   - Resolved: biometric + PIN app lock is implemented and shipped
     as of the v0.1 stabilization pass. Lock-on-resume is opt-in.

5. **Should backups be plain export files, encrypted export files, or
   both?**
   - Resolved: both. Plain JSON is the default export format and is
     also accepted on import. Encrypted export/import using a
     user-supplied password is available in the export/import screen.

6. **Should this be released only on GitHub first, or also prepared for
   Play Store/App Store/F-Droid?**
   - Resolved for v0.1: GitHub only. Store-prep work (descriptions,
     screenshots, signing, age-rating questionnaire) is out of scope
     for the prototype.

7. **What name should the app use publicly: Card Box, Free Card Wallet,
   Open Card Box, or something else?**
   - Resolved: Card Box is the public name for v0.1. A different
     public name can be revisited later if needed.

8. **What is the minimum useful version for you personally, using your
   current pile of cards?**
   - Resolved: the v0.1 prototype already covers the user's personal
     card pile (loyalty, access, transit, library). Emulation is the
     only gap, and it is a known-shipping-later track.

9. **Should the first prototype prioritize Android or Android/iOS
   together?**
   - Resolved: Flutter with Android first; iOS is a planned second
     target. iOS support is not validated end-to-end in v0.1.

10. **Should card photos be included in the first prototype?**
    - Resolved: yes. Both front and back images are first-class
      fields on the card model.

11. **Should the app include a card compatibility test flow?**
    - Resolved: yes. The compatibility-test screen is in the v0.1
      prototype and writes back a `compatibilityStatus` on the card.

12. **Which real cards should be used for acceptance testing?**
    - Resolved: office access card, supermarket loyalty card,
      metro/transit card, library card, and similar common cards.
      No private card numbers are recorded in test artifacts.

## Deferred (2026-06-13)

The following two questions were on the original v0.1 wishlist and are
now explicitly deferred to a later pass. They are tracked here so a
future reader can see the decision trail. See DR-013 for the full
reasoning.

13. **When should expiry reminders be added?**
    - Deferred. Expiry reminders need a notification permission, a
      scheduled notification service, a timezone-aware scheduling
      strategy, and an "expiring soon" UX. Each piece is substantial
      and benefits from its own stabilization pass. The data model
      does not yet track card expiry dates.

14. **When should acceptance locations be added?**
    - Deferred. Acceptance locations need a geolocation permission, a
      per-card "where this card is accepted" model, and a proximity
      search. The privacy story for a local-first app that wants to
      do "which of my cards works here" without sending coordinates
      anywhere is non-trivial and deserves a dedicated decision
      record when it is designed.
