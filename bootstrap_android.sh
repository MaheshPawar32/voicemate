#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK was not found. Install Flutter and ensure 'flutter' is on PATH." >&2
  exit 1
fi

NATIVE_SOURCE="$ROOT/android/app/src/main/kotlin/com/dev/voicemate"
if [[ ! -f "$NATIVE_SOURCE/MainActivity.kt" ]]; then
  echo "Native VoiceMate Kotlin sources were not found at: $NATIVE_SOURCE" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
cleanup() { rm -rf "$WORK_DIR"; }
trap cleanup EXIT

mkdir -p "$WORK_DIR/native/com/dev"
cp -R "$NATIVE_SOURCE" "$WORK_DIR/native/com/dev/voicemate"

flutter create --platforms=android --org com.dev --project-name voicemate "$WORK_DIR/generated"

# Replace the prototype-only Android folder with Flutter's generated, complete
# Android project (Gradle wrapper, settings, app config, resources and manifest).
rm -rf "$ROOT/android"
cp -R "$WORK_DIR/generated/android" "$ROOT/android"
cp "$WORK_DIR/generated/.metadata" "$ROOT/.metadata"

mkdir -p "$ROOT/android/app/src/main/kotlin/com/dev/voicemate"
cp -R "$WORK_DIR/native/com/dev/voicemate/." "$ROOT/android/app/src/main/kotlin/com/dev/voicemate/"

MANIFEST="$ROOT/android/app/src/main/AndroidManifest.xml"
if [[ ! -f "$MANIFEST" ]]; then
  echo "Flutter did not generate AndroidManifest.xml." >&2
  exit 1
fi

if ! grep -q 'android.permission.RECORD_AUDIO' "$MANIFEST"; then
  sed -i.bak '/<manifest /a\
    <uses-permission android:name="android.permission.RECORD_AUDIO" />\
    <uses-feature android:name="android.hardware.microphone" android:required="false" />' "$MANIFEST"
  rm -f "$MANIFEST.bak"
fi

sed -i.bak 's/android:label="voicemate"/android:label="VoiceMate"/' "$MANIFEST"
rm -f "$MANIFEST.bak"

APP_GRADLE_KTS="$ROOT/android/app/build.gradle.kts"
APP_GRADLE="$ROOT/android/app/build.gradle"
if [[ -f "$APP_GRADLE_KTS" ]]; then
  sed -i.bak 's/minSdk = flutter.minSdkVersion/minSdk = 23/' "$APP_GRADLE_KTS"
  rm -f "$APP_GRADLE_KTS.bak"
elif [[ -f "$APP_GRADLE" ]]; then
  sed -i.bak 's/minSdkVersion flutter.minSdkVersion/minSdkVersion 23/' "$APP_GRADLE"
  rm -f "$APP_GRADLE.bak"
fi

cd "$ROOT"
flutter pub get

echo
echo "Android project scaffold generated."
echo "Application ID expected: com.dev.voicemate"
echo "Next run: flutter analyze && flutter test && flutter run"
