# AdMob setup

Vokey's AdMob IDs are configured in code (they are public — every APK contains them):

| Item | ID |
|---|---|
| App ID | `ca-app-pub-3548177810801627~3283313382` |
| Banner | `ca-app-pub-3548177810801627/1046006167` |
| Interstitial | `ca-app-pub-3548177810801627/4331691239` |
| Native | `ca-app-pub-3548177810801627/9471291092` |

## Which IDs a build uses
- **Release** builds: production IDs (App ID via `android/app/build.gradle.kts` release `manifestPlaceholders`, unit IDs via `lib/core/ads/ad_ids.dart`).
- **Debug / profile** builds and `flutter test`: Google's public test IDs. Never load live ads during development — AdMob treats it as invalid traffic.
- **Debug-signed release for QA** (CI's release-test APK): built with `--dart-define=ADMOB_USE_TEST_IDS=true`. Note the App ID in that APK is still production; that is allowed with test *units*.
- Overrides: `-PadmobAppId=...` (Gradle) and `--dart-define=ADMOB_BANNER_ID / ADMOB_INTERSTITIAL_ID / ADMOB_NATIVE_ID`.

## Current placements
- Banner: Home, only while monitoring is off and nothing is busy.
- Interstitial and Native: unit IDs configured, **no placements implemented yet**. Rules from the product spec apply: never during monitoring, alerts, onboarding, permission flows or Finder Test.

## Before release
- Add `app-ads.txt` on the developer website listed in Play Console.
- Complete UMP/consent messages in AdMob (GDPR/US states) — the app already runs the UMP flow before any ad request.
- Update the Play Data safety form for the Google Mobile Ads SDK.
