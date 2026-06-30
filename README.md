# Passly

Passly is an iOS 17+ SwiftUI foundation for a premium Apple Wallet pass maker. It supports premium-gated card creation, local card vault UX, import entry points, safe NFC/NDEF wording, mock pass generation, RevenueCat monetization, and a Firebase Cloud Functions signing layer for real `.pkpass` export.

## What is included

- Native SwiftUI app with SwiftData persistence.
- Seven-page animated onboarding with premium pass visuals and NFC safety copy.
- Home vault, search, settings, paywall, add-card hub, manual editor, paste flow, scanner flow, card detail, card flip, QR/barcode display, Wallet preview, reminders, and Face ID reveal hooks.
- Service protocols for auth, import analysis, NFC, Wallet, pass generation, remote config, analytics, and repositories.
- RevenueCat entitlement gating for Monthly Pro and Lifetime Pro.
- Mock pass generation so the app stays useful before Apple pass certificates are configured.
- Firebase Functions v2 package, Firestore rules, Storage rules, and Remote Config template.

## Build

Open `Passly.xcodeproj` in Xcode and run the `Passly` scheme on an iOS 17+ simulator or device.

Camera, NFC, Face ID, Apple Wallet presentation, and notification behavior need a physical iPhone for full verification. The simulator can still run the app shell, onboarding, manual creation, search, editor, and mock pass generation.

## Backend integration

Real Apple Wallet export requires Apple Pass Type ID credentials stored in Google Secret Manager. Do not put certificates or private keys in the iOS app or in Git.

Required secrets:

- `PASS_TYPE_IDENTIFIER`
- `APPLE_TEAM_ID`
- `APPLE_WWDR_CERTIFICATE_PEM`
- `APPLE_PASS_CERTIFICATE_PEM`
- `APPLE_PASS_PRIVATE_KEY_PEM`
- `APPLE_PASS_CERTIFICATE_PASSWORD`

See [docs/FIREBASE_INTEGRATION.md](docs/FIREBASE_INTEGRATION.md).

## Monetization

Passly can be downloaded without purchase, but creation is locked until the user unlocks Pro. Users can view onboarding and the locked app shell, then unlock all creation/import/export features with RevenueCat:

- `passly.monthly.pro` at `$6.99/month`
- `passly.lifetime.pro` at `$29.99` launch price
- RevenueCat entitlement: `pro`

Replace `REVENUECAT_PUBLIC_SDK_KEY` in `RevenueCatConfig` before purchase testing.

## Safety positioning

Passly creates user-generated Wallet passes from QR codes, barcodes, photos, PDFs, links, manual entries, and readable NFC/NDEF tags.

Passly does not copy payment cards, access cards, hotel keys, car keys, transit cards, government IDs, or secure NFC credentials.
