#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter SDK was not found. Install Flutter and ensure 'flutter' is on PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Python 3 is required to patch the generated Gradle target SDK." >&2
  exit 1
fi

NATIVE_SOURCE="$ROOT/android/app/src/main/kotlin/com/dev/voicemate"
if [[ ! -f "$NATIVE_SOURCE/MainActivity.kt" ]]; then
  echo "Native VoiceMate Kotlin sources were not found at: $NATIVE_SOURCE" >&2
  exit 1
fi

ICON_SOURCE="$ROOT/assets/branding/voicemate_icon_512.png"
if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "VoiceMate icon is missing: $ICON_SOURCE" >&2
  echo "Extract the Play Store artwork pack into the repository root first." >&2
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

# Google Play requires new apps to target Android 16 / API 36 or higher
# for submissions from 31 August 2026. Make this explicit in generated Gradle.
python3 - "$ROOT/android/app" <<'PY'
from pathlib import Path
import re
import sys

app_dir = Path(sys.argv[1])
for name in ("build.gradle.kts", "build.gradle"):
    path = app_dir / name
    if not path.exists():
        continue
    text = path.read_text()
    text = re.sub(r'targetSdk\s*=\s*flutter\.targetSdkVersion', 'targetSdk = 36', text)
    text = re.sub(r'targetSdkVersion\s+flutter\.targetSdkVersion', 'targetSdkVersion 36', text)
    path.write_text(text)
    if not re.search(r'targetSdk\s*=\s*36|targetSdkVersion\s+36', text):
        raise SystemExit(f"Could not set target SDK 36 in {path}")
    break
else:
    raise SystemExit("Could not find Android app Gradle configuration.")
PY

cd "$ROOT"
flutter pub get
dart run flutter_launcher_icons

echo
echo "Android project scaffold and VoiceMate launcher icon generated."
echo "Application ID expected: com.dev.voicemate"
echo "Target SDK configured: 36"
echo "Next run: flutter analyze && flutter test && flutter run"
