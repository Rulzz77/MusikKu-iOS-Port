# Test MusikKu iOS from Windows with Appetize

This guide lets you preview the native iOS port from a Windows PC without a physical iPhone or a local Mac.

## What gets built

The iOS GitHub Actions workflow produces two different files:

- `MusikKu-iOS-Simulator-Appetize.zip`: a ZIP containing the ARM64 iOS Simulator `.app` bundle. This is the file Appetize needs.
- `MusikKu-iOS-unsigned.ipa` (inside the `MusikKu-iOS-unsigned-IPA` artifact): an unsigned device build for physical-iPhone testing with a sideloading tool. **Do not upload this IPA to Appetize.**

Appetize accepts compressed iOS Simulator `.app` bundles (ZIP or TAR.GZ), not IPA files. See the [Appetize iOS upload requirements](https://docs.appetize.io/platform/app-management/uploading-apps/ios) and [IPA support note](https://support.appetize.io/can-i-use-an-ipa-file-to-upload-an-ios-app-to-appetize.io).

## Build and download from Windows

1. Open the [iOS Build workflow](https://github.com/Rulzz77/MusikKu-iOS-Port/actions/workflows/ios-build.yml).
2. Open the newest successful run for branch `phase-1-ui-library-queue` or the pull request.
3. In the Artifacts section, download **MusikKu-iOS-Simulator-Appetize**.
4. Extract the downloaded GitHub artifact ZIP. Inside it is `MusikKu-iOS-Simulator-Appetize.zip`. Keep this inner ZIP intact; it contains `MusikKu.app`.
5. Open [Appetize](https://appetize.io/), sign in or create an account, and use its app upload flow to upload the inner `MusikKu-iOS-Simulator-Appetize.zip` as an iOS app.
6. When Appetize finishes processing, open the app page in Chrome or Edge and start an iPhone simulator session.

The GitHub artifact is retained for 7 days, so download it before it expires.

## What you can test

Use the browser simulator to inspect the SwiftUI screens and exercise touch interactions: Beranda, Explore, Koleksi, search, playlist screens, queue and player controls. It is also useful for catching layout, navigation and launch crashes.

## What this does not prove

Appetize runs an iOS Simulator build, not a real iPhone. A successful session does not prove that YouTube's live attestation/token challenge succeeds, that a song produces audible output on real hardware, or that background playback, lock-screen controls, Bluetooth/headset routing and interruption handling behave exactly like a physical iPhone. Keep those checks on the physical-device release checklist.

If Appetize rejects the upload, confirm that you selected the inner `MusikKu-iOS-Simulator-Appetize.zip` and not the outer GitHub artifact ZIP or the unsigned IPA.
