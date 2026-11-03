# VoiceMate – Voice Control & Phone Finder

**Your phone listens. Your phone responds.**

VoiceMate is an Android-only, offline-first phone utility built with Flutter and Kotlin.

> Status: Flutter UI foundation and an early foreground-only clap-test prototype are committed. The production background finder, validated clap/whistle detection, and offline speech recognition are not implemented yet.

## Product principles
- Android application ID: `com.dev.voicemate`
- Flutter UI + Kotlin Android services.
- VelocityX/VxStore for the agreed state approach; Hive for local settings.
- No login, backend, cloud database, or analytics.
- Audio processing stays on-device; raw microphone recordings are never persisted.
- Background microphone monitoring starts only after explicit user action and uses a visible foreground-service notification.
- AdMob only; ads never interrupt monitoring, alerts, onboarding, or permission flows.
- Core utility must work without internet.

## Repository guide
- `docs/PRODUCT_SPEC.md` – requirements and screen inventory
- `docs/UI_SPEC.md` – visual direction and screen design
- `docs/ARCHITECTURE.md` – Flutter/Kotlin boundaries
- `docs/ROADMAP.md` – phased implementation
- `docs/PRIVACY_AND_PLAY_COMPLIANCE.md` – privacy and release checklist
- `docs/CLAP_TESTING_GUIDE.md` – test the foreground clap prototype
- `docs/PLAY_STORE_LISTING.md` – Play listing copy and release checklist
- `privacy_policy.html` – privacy policy draft; replace the contact placeholder before publishing
- `assets/branding/` – Play icon and feature graphic (from the artwork pack)

## Setup

1. Download the VoiceMate Play Store Artwork Pack and extract it into this repository root. This adds the 512px launcher icon source and store artwork.
2. Install Flutter stable, Android SDK and Python 3.
3. Run the bootstrap script **once** to generate the Android Gradle project and launcher icons:

```bash
chmod +x bootstrap_android.sh
./bootstrap_android.sh
```

4. Then run:

```bash
flutter analyze
flutter test
flutter run
```

The script generates the Android platform wrapper, adds the microphone permission, configures target SDK 36 and generates the Android launcher icon. Verify the application ID is exactly `com.dev.voicemate` and check the generated Gradle target SDK before release. Do not rerun the bootstrap script after making custom Android project changes because it regenerates the Android directory.

## Store listing and policy

The repository includes a privacy policy draft and Play Store metadata checklist. The privacy policy is not yet hosted at a public HTTPS URL. To publish it, enable GitHub Pages for this repository (deploy from the main branch root); then verify the public page at:

`https://maheshpawar32.github.io/voicemate/privacy_policy.html`

Replace `REPLACE_WITH_SUPPORT_EMAIL` before publishing. Add the final policy URL inside the app and in Play Console. The artwork pack's screen images are design mockups, not genuine app screenshots; capture screenshots from the built app for Play submission.

## Engineering rules
Inspect before editing. Implement one vertical slice at a time. Keep algorithms outside widgets. Use snake_case for persisted fields. Keep one microphone capture owner. Never start microphone monitoring secretly. Report tests honestly; do not claim untested features work.
