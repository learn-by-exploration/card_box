# Open Questions

These questions should be answered before locking the MVP requirement baseline.

1. Which card categories matter most for the first release?
   - Loyalty and membership cards
   - Office/building access cards
   - Student/library cards
   - Transit cards
   - Gift cards
   - Personal IDs
   - Current answer: support whatever is realistically possible on Android and
     iOS, excluding credit and debit cards.
2. Is the main pain "too many cards in wallet" or "want the phone to act like
   the card"?
   - Current answer: both. Store cards and eventually act like physical
     RFID/NFC cards where possible.
3. Should the first MVP avoid card emulation entirely and focus on organization,
   barcode/QR, camera, and NFC reading?
   - Decision: yes for MVP usefulness, with emulation as a later Android-first
     capability track.
4. Do users need encryption/passcode/biometric unlock from day one?
   - Current answer: not necessary on day one, but definitely wanted.
5. Should backups be plain export files, encrypted export files, or both?
   - Current direction: user-controlled export because the project should not
     require hosting.
   - v0.1 answer: plain JSON for prototype; encrypted export before public
     release.
6. Should this be released only on GitHub first, or also prepared for Play
   Store/App Store/F-Droid?
7. What name should the app use publicly: Card Box, Free Card Wallet, Open Card
   Box, or something else?
   - Current answer: Card Box is good for now. Revisit if a simpler/creative
     public name appears.
8. What is the minimum useful version for you personally, using your current
   pile of cards?
9. Should the first prototype prioritize Android or Android/iOS together?
   - Current answer: Flutter with Android first; iOS later.
10. Should card photos be included in the first prototype?
   - Current answer: yes.
11. Should the app include a card compatibility test flow?
   - Current answer: yes.
12. Which real cards should be used for acceptance testing?
   - Current answer: office access card, supermarket loyalty card, metro/transit
     card, library card, and similar common cards. Do not record private card
     numbers in test artifacts.
