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
- AdMob only. Ads never interrupt monitoring, alerts, onboarding, or permission flows.
- Core utility must work without internet.

## Planned features
Smart Phone Finder, Clap Detection, Whistle Detection, Offline Voice Commands, optional Screen Lock shortcut, Alert Studio, Sound Library, Monitoring Centre, History, Battery & Performance, Privacy Centre.

## Repository guide
- `docs/PRODUCT_SPEC.md` – requirements and screen inventory
- `docs/UI_SPEC.md` – visual direction and screen design
- `docs/ARCHITECTURE.md` – Flutter/Kotlin boundaries
- `docs/ROADMAP.md` – phased implementation
- `docs/PRIVACY_AND_PLAY_COMPLIANCE.md` – privacy and release checklist
- `docs/CLAP_TESTING_GUIDE.md` – generate Android scaffold and test the visible clap prototype
- `lib/` – Flutter source

## Setup
Install Flutter stable and the Android SDK, then run:

```bash
flutter pub get
flutter analyze
flutter test
flutter run
```

The repository contains Kotlin source for the visible clap-test prototype, but not Flutter-generated Gradle files or the Android manifest yet. Generate the official Android scaffold and merge the native files with:

```bash
chmod +x bootstrap_android.sh
./bootstrap_android.sh
```

The script uses your installed Flutter SDK, keeps the existing Dart/Kotlin source, adds the microphone permission, and generates the Android wrapper. Verify the application ID is exactly `com.dev.voicemate` before running.

## Engineering rules
Inspect before editing. Implement one vertical slice at a time. Keep algorithms outside widgets. Use snake_case for persisted fields. Keep one microphone capture owner. Never start microphone monitoring secretly. Report tests honestly; do not claim unimplemented features work.
