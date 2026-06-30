# Implementation Status

## Implemented in this scaffold

- iOS 17 SwiftUI app project.
- SwiftData `WalletCard` model and repository.
- Premium design system primitives.
- Seven animated onboarding pages.
- Home vault with card stack, search, recent/favorites/expiry sections, duplicate/archive actions.
- Add Card hub for camera, photo, PDF, paste, NFC, templates, clipboard, `.pkpass` placeholder, and link import path.
- Manual editor with content, code, design, reminders, and privacy fields.
- Camera barcode scanner using AVFoundation metadata detection.
- Photo barcode analysis using Vision.
- NFC NDEF text/URL reading service with required safety copy.
- Card detail with 3D flip, QR/barcode display, private field unlock hook, Wallet preview, mock pass generation.
- Paywall UI with RevenueCat entitlement gating for monthly and lifetime unlocks.
- Firebase Cloud Functions v2 signing interface.
- Firestore/Storage rules and Remote Config flags.

## Production work still needed

- Add a paid Apple Developer team ID and signing settings.
- Add Firebase iOS SDKs and `GoogleService-Info.plist`.
- Add real Firebase Auth, Firestore sync, Storage upload, Remote Config, Crashlytics, Analytics, and App Check implementations behind the existing protocols.
- Add Apple Pass Type ID certificate, WWDR certificate, private key, and pass assets in Secret Manager.
- Replace the placeholder pass model path in the function package with a real pass model folder containing icon assets.
- Add real RevenueCat public SDK key, Offering, products, and `pro` entitlement in the RevenueCat dashboard.
- Add Share Extension target.
- Run camera/NFC/Wallet flows on a physical iPhone.
