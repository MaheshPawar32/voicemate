# VoiceMate AdMob and UMP setup

VoiceMate uses Google Mobile Ads Flutter plugin 9.2.0 with the User Messaging Platform (UMP) consent flow. Android builds use the Google Mobile Ads Next-Gen SDK.

## AdMob console setup

1. Create the Android VoiceMate app in AdMob with package ID `com.dev.voicemate`.
2. Copy the AdMob App ID (format `ca-app-pub-...~...`).
3. Create one Banner ad unit and copy the Banner unit ID (format `ca-app-pub-.../...`).
4. In AdMob Privacy & messaging, publish the consent messages needed for the regions where the app will be distributed. Configure privacy options when required.
5. Complete the Google Play Data safety declaration against the exact SDK versions and configuration in the release.

## Production build

Pass your real AdMob App ID as a Gradle project property and the real Banner unit ID as a Dart compile-time value:

```bash
ORG_GRADLE_PROJECT_admobAppId='ca-app-pub-APP~APPID' \
flutter build appbundle --release \
  --dart-define=USE_NEXT_GEN_SDK=true \
  --dart-define=ADMOB_BANNER_ID=ca-app-pub-APP/BANNER
```

The Android App ID is injected into AndroidManifest.xml by `bootstrap_android.sh`. The banner widget does not fall back to a Google test unit in release builds. When no production banner ID is supplied, it shows no ad.

## Development and CI

Debug builds use Google's official test App ID and Banner unit ID. CI builds Android with `USE_NEXT_GEN_SDK=true`, minimum Android API 24 and compile/target API 36.

Never publish a build that still uses Google test ad identifiers.

## App behavior

- UMP refreshes consent information at app startup.
- Any consent form required by UMP is presented before ads are requested.
- Ad requests are gated by UMP's `canRequestAds()` result.
- The only placement is a Home banner while finder monitoring is idle.
- Banners are hidden during finder monitoring and start/stop transitions, and are not shown on the microphone test, onboarding, alert preview, permission or other feature screens.
- Ad failures do not block the finder or local features.
- Settings exposes the UMP privacy options form when UMP indicates that it is required.
- Do not place ads in the microphone service or in the alert/permission flows.

Before release, verify the real AdMob App ID and Banner unit ID in a signed internal-test build. Update the external privacy policy and Google Play Data safety form to reflect the exact SDK configuration shipped.
