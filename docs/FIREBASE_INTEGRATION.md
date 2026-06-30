# Firebase Integration

## iOS

The app currently uses local/mock services so it builds without embedding Firebase SDKs. To enable production Firebase behavior:

1. Add Firebase iOS SDK packages in Xcode:
   - FirebaseAuth
   - FirebaseFirestore
   - FirebaseStorage
   - FirebaseRemoteConfig
   - FirebaseAnalytics
   - FirebaseCrashlytics
   - FirebaseAppCheck
2. Add `GoogleService-Info.plist` to the app target.
3. Replace `LocalAnonymousAuthService`, `LocalRemoteConfigService`, and `MockPassGenerationService` in `DependencyContainer` with Firebase-backed implementations.
4. Configure App Check with DeviceCheck or App Attest.

The app should continue to work offline using SwiftData even if Firebase is unreachable.

## Functions

Install and build:

```bash
cd firebase/functions
npm install
npm run build
```

Deploy:

```bash
firebase deploy --only functions,firestore:rules,storage
```

## Pass Signing

Wallet passes must be signed server-side. The Cloud Function reads Apple pass credentials from Secret Manager, creates a `.pkpass`, stores it under:

```text
users/{uid}/cards/{cardId}/generated/{serialNumber}.pkpass
```

Then it returns a short-lived signed URL for the authenticated owner.

## App Review Notes

Passly creates user-generated Apple Wallet passes from QR codes, barcodes, photos, PDFs, links, manual entries, and readable NFC/NDEF tags.

NFC functionality is limited to reading public NDEF tag text or URLs. The app does not copy payment cards, access cards, hotel keys, car keys, transit cards, government IDs, or secure NFC credentials.

Apple Wallet pass generation is performed by a Firebase backend that signs `.pkpass` files securely. Signing certificates and private keys are not embedded in the iOS app.
