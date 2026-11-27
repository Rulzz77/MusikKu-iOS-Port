# MusikKu iOS — Release Readiness

This document records what must be completed before merging PR #1 and distributing MusikKu iOS. A green CI build is not a substitute for device playback tests, App Store authorization, signing, or content-rights review.

## Engineering readiness

- [x] Native iOS target and simulator build
- [x] App Store-sized AppIcon source, asset-catalog integration and CFBundleIconName
- [x] Privacy manifest declares app-local UserDefaults access (CA92.1); App Store Connect privacy answers and privacy policy are still outstanding
- [x] Simulator UI preview artifact
- [x] Appetize simulator ZIP artifact for browser-based UI checks
- [x] Unsigned arm64 IPA artifact for sideload testing
- [ ] Latest playback fallback, root-layout, AppIcon and privacy changes pass a complete CI run
- [ ] Physical iPhone: resolve and play multiple ordinary tracks
- [ ] Physical iPhone: seek, pause/resume, next/previous, repeat and shuffle
- [ ] Physical iPhone: background playback, lock screen, Control Center and interruptions
- [ ] Physical iPhone: Bluetooth/AirPlay route changes and Wi-Fi/cellular handoff
- [ ] Verify resolver fallback across audio-only AAC and muxed AAC MP4; record actual profile/MIME outcome
- [ ] Verify no signed media URL, request header, visitor token, or PO token appears in logs, crash reports, screenshots, or analytics
- [ ] Inspect all supported screens on iPhone and iPad; review accessibility, text scaling and empty/error/loading states

## Release, signing and store setup

- [ ] Select the final reverse-DNS bundle identifier and confirm it is available in the Apple Developer account
- [ ] Set the Apple Developer Team ID; configure distribution certificate and App Store provisioning profile in a secure signing pipeline
- [ ] Set the release marketing version and monotonically increasing build number
- [ ] Create the App Store Connect app record and configure SKU, age rating, category, pricing/territories and availability
- [ ] Provide app name, subtitle, description, keywords, support URL, marketing URL, screenshots and 1024px store artwork
- [ ] Publish an accessible privacy policy and link it in App Store Connect and inside the app
- [ ] Complete App Privacy disclosures for the app and all third-party services/SDKs based on the actual data transmitted and retained
- [ ] Confirm privacy manifest coverage for every linked SDK/framework; update it if dependencies access additional required-reason APIs
- [ ] Archive and export a signed Release build; validate with Xcode Organizer/Transporter and TestFlight
- [ ] Run a final TestFlight regression on real devices before App Store submission

## Mandatory content-rights and platform-policy gate

MusikKu currently resolves YouTube Music catalogue/player data through InnerTube endpoints and plays extracted media through AVPlayer. This is not an official YouTube playback embed/API integration. Before public distribution, obtain and document permission/licensing that covers the third-party music playback and any trademarks/content shown, and have the implementation reviewed against YouTube's terms and Apple App Review requirements. Apple says apps that let users stream third-party content must provide authorization from the rights holder/service where required. YouTube's terms restrict using content or circumventing service/security restrictions unless expressly authorized. Do not submit to the App Store until this gate is resolved.

References:
- Apple App Review Guidelines: https://developer.apple.com/app-store/review/guidelines/
- Apple complete-review evidence for third-party content streaming: https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/
- YouTube Terms of Service: https://www.youtube.com/t/terms
- Apple App Privacy Details: https://developer.apple.com/app-store/app-privacy-details/

## Distribution obligations

The repository includes GPL-3.0-licensed derivative code and third-party notices. Before distributing binaries, confirm the applicable GPL-3.0 source, license, attribution and corresponding-source obligations are met for the exact source and binary being distributed. Include the source location and notices with the release materials.

## Current distribution status

- CI unsigned IPA is for development/sideload validation only; it is not an App Store-ready signed archive.
- Appetize iOS Simulator sessions are useful for UI and flow testing but do not produce audible output. Real audio verification requires an actual iPhone or another supported audio-capable test environment.
- PR #1 must remain open until all engineering and policy gates above are satisfied. Merge and release are intentionally not performed by this preparation work.
