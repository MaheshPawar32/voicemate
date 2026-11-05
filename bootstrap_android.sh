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
GENERATE_ICON=false
if [[ -f "$ROOT/android/gradlew" || -f "$ROOT/android/gradlew.bat" ]]; then
  echo "Android scaffolding already exists. Refusing to delete or regenerate it." >&2
  echo "To rebuild, use flutter clean; do not rerun this bootstrap script." >&2
  exit 1
fi
if [[ -f "$ICON_SOURCE" ]]; then
  GENERATE_ICON=true
else
  echo "Icon source not found. Android will keep the default Flutter icon."
  echo "Extract the artwork pack and run: dart run flutter_launcher_icons"
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

# Include optional Device Admin resources for the lock-only shortcut.
if [[ -d "$ROOT/android_res" ]]; then
  mkdir -p "$ROOT/android/app/src/main/res/xml"
  cp -R "$ROOT/android_res/xml/." "$ROOT/android/app/src/main/res/xml/"
fi

ANDROID_TEST_SOURCE="$ROOT/android_test_src"
if [[ -d "$ANDROID_TEST_SOURCE" ]]; then
  mkdir -p "$ROOT/android/app/src/test/kotlin/com/dev/voicemate"
  cp -R "$ANDROID_TEST_SOURCE/." "$ROOT/android/app/src/test/kotlin/com/dev/voicemate/"
fi

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

# Configure the explicit, user-started microphone foreground service.
python3 - "$MANIFEST" <<'PY'
from pathlib import Path
import re
import sys

manifest = Path(sys.argv[1])
text = manifest.read_text()
permissions = [
    "android.permission.FOREGROUND_SERVICE",
    "android.permission.FOREGROUND_SERVICE_MICROPHONE",
    "android.permission.VIBRATE",
    "android.permission.POST_NOTIFICATIONS",
    "android.permission.INTERNET",
    "android.permission.CAMERA",
]
for permission in permissions:
    tag = f'<uses-permission android:name="{permission}" />'
    if permission not in text:
        match = re.search(r'<uses-permission[^>]*/>', text)
        if match:
            text = text[:match.end()] + "\n    " + tag + text[match.end():]
        else:
            root = re.search(r'<manifest\b[^>]*>', text)
            if not root:
                raise SystemExit("Android manifest root element was not found.")
            text = text[:root.end()] + "\n    " + tag + text[root.end():]

camera_features = """    <uses-feature
        android:name="android.hardware.camera"
        android:required="false" />
    <uses-feature
        android:name="android.hardware.camera.flash"
        android:required="false" />"""
if "android.hardware.camera" not in text:
    text = text.replace("</manifest>", camera_features + "\n</manifest>", 1)
elif "android.hardware.camera.flash" not in text:
    text = text.replace("</manifest>", """    <uses-feature
        android:name="android.hardware.camera.flash"
        android:required="false" />
</manifest>""", 1)

service_tag = """        <service
            android:name=".VoiceMonitoringService"
            android:exported="false"
            android:foregroundServiceType="microphone" />"""
if ".VoiceMonitoringService" not in text:
    text = text.replace("</application>", service_tag + "\n    </application>", 1)

receiver_tag = """        <receiver
            android:name=".VoiceMateDeviceAdminReceiver"
            android:permission="android.permission.BIND_DEVICE_ADMIN"
            android:exported="true">
            <meta-data
                android:name="android.app.device_admin"
                android:resource="@xml/voicemate_device_admin" />
            <intent-filter>
                <action android:name="android.app.action.DEVICE_ADMIN_ENABLED" />
            </intent-filter>
        </receiver>"""
if ".VoiceMateDeviceAdminReceiver" not in text:
    text = text.replace("</application>", receiver_tag + "\n    </application>", 1)

admob_meta_tag = """        <meta-data
            android:name="com.google.android.gms.ads.APPLICATION_ID"
            android:value="${admobAppId}" />"""
if "com.google.android.gms.ads.APPLICATION_ID" not in text:
    text = text.replace("</application>", admob_meta_tag + "\n    </application>", 1)
manifest.write_text(text)
PY

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
    text = re.sub(r'minSdk\s*=\s*flutter\.minSdkVersion', 'minSdk = 24', text)
    text = re.sub(r'minSdkVersion\s+flutter\.minSdkVersion', 'minSdkVersion 24', text)
    text = re.sub(r'compileSdk\s*=\s*flutter\.compileSdkVersion', 'compileSdk = 36', text)
    text = re.sub(r'compileSdkVersion\s+flutter\.compileSdkVersion', 'compileSdkVersion 36', text)
    # Vosk 0.3.75 ships a 32-bit ARM libvosk.so with 4 KB ELF LOAD
    # alignment. Keep 64-bit Android targets, whose Vosk binaries pass
    # the 16 KB ELF check; do not package the incompatible armeabi-v7a ABI.
    if name.endswith(".kts"):
        abi_config = """        ndk {
            abiFilters += setOf("arm64-v8a", "x86_64")
        }
"""
        if "abiFilters" not in text:
            if not re.search(r'defaultConfig\s*\{', text):
                raise SystemExit("Could not find defaultConfig to configure supported ABIs.")
            text = re.sub(
                r'(defaultConfig\s*\{)',
                lambda match: match.group(1) + chr(10) + abi_config,
                text,
                count=1,
            )
        # Flutter's target-platform flag does not filter native libraries
        # contributed by every Android AAR. Explicitly exclude Vosk's unused
        # 32-bit ARM payload at APK packaging time as a second, enforceable guard.
        packaging_config = """    packaging {
        jniLibs {
            excludes += setOf("**/armeabi-v7a/**")
        }
    }
"""
        if "excludes += setOf(\"**/armeabi-v7a/**\")" not in text:
            if not re.search(r'android\s*\{', text):
                raise SystemExit("Could not find android block to exclude the incompatible 32-bit ABI.")
            text = re.sub(
                r'(android\s*\{)',
                lambda match: match.group(1) + chr(10) + packaging_config,
                text,
                count=1,
            )
        if "excludes += setOf(\"**/armeabi-v7a/**\")" not in text:
            raise SystemExit("Could not configure 32-bit ARM native-library packaging exclusion.")
    path.write_text(text)
    if not re.search(r'targetSdk\s*=\s*36|targetSdkVersion\s+36', text):
        raise SystemExit(f"Could not set target SDK 36 in {path}")
    if not re.search(r'minSdk\s*=\s*24|minSdkVersion\s+24', text):
        raise SystemExit(f"Could not set minimum SDK 24 for GMA Next-Gen in {path}")
    if not re.search(r'compileSdk\s*=\s*36|compileSdkVersion\s+36', text):
        raise SystemExit(f"Could not set compile SDK 36 for GMA Next-Gen in {path}")

    if name.endswith(".kts") and 'manifestPlaceholders["admobAppId"]' not in text:
        placeholder = '        manifestPlaceholders["admobAppId"] = project.findProperty("admobAppId")?.toString() ?: "ca-app-pub-3940256099942544~3347511713"' + chr(10)
        if re.search(r'defaultConfig\s*\{', text):
            text = re.sub(
                r'(defaultConfig\s*\{)',
                lambda match: match.group(1) + chr(10) + placeholder,
                text,
                count=1,
            )
        else:
            raise SystemExit("Could not add the AdMob app ID manifest placeholder.")

    # Add Vosk for entirely on-device speech recognition. The speech model is
    # downloaded once after user consent and remains in app-private storage.
    if name.endswith(".kts") and "com.alphacephei:vosk-android" not in text:
        dependency = '    implementation("com.alphacephei:vosk-android:0.3.75")\n'
        if re.search(r'dependencies\s*\{', text):
            text = re.sub(
                r'(dependencies\s*\{)',
                lambda match: match.group(1) + "\n" + dependency,
                text,
                count=1,
            )
        else:
            text += "\ndependencies {\n" + dependency + "}\n"

    # Add JUnit 4 so the native Kotlin detector unit tests compile.
    if "junit:junit" not in text:
        if name.endswith(".kts"):
            dependency = '    testImplementation("junit:junit:4.13.2")\n'
        else:
            dependency = "    testImplementation 'junit:junit:4.13.2'\n"
        if re.search(r'dependencies\s*\{', text):
            text = re.sub(
                r'(dependencies\s*\{)',
                lambda match: match.group(1) + "\n" + dependency,
                text,
                count=1,
            )
        else:
            text += "\ndependencies {\n" + dependency + "}\n"
        # Keep release signing credentials outside the repository. CI or a local
    # developer supplies android/key.properties and android/app/*.jks.
    if name.endswith(".kts"):
        imports = """import java.io.FileInputStream
import java.util.Properties

"""
        prelude = """val keystoreProperties = Properties()
val keystorePropertiesFile = rootProject.file("key.properties")
if (keystorePropertiesFile.exists()) {
    keystoreProperties.load(FileInputStream(keystorePropertiesFile))
}

"""
        signing_block = """    signingConfigs {
        if (keystorePropertiesFile.exists()) {
            create("release") {
                keyAlias = keystoreProperties["keyAlias"] as String
                keyPassword = keystoreProperties["keyPassword"] as String
                storeFile = file(keystoreProperties["storeFile"] as String)
                storePassword = keystoreProperties["storePassword"] as String
            }
        }
    }

"""
        text = imports + text
        text = text.replace("android {", prelude + "android {", 1)
        text = text.replace("android {", "android {\n" + signing_block, 1)
        debug_signing = 'signingConfig = signingConfigs.getByName("debug")'
        release_signing = 'signingConfig = if (keystorePropertiesFile.exists()) signingConfigs.getByName("release") else signingConfigs.getByName("debug")'
        if debug_signing not in text:
            raise SystemExit("Flutter Gradle template did not contain the expected debug release-signing placeholder.")
        text = text.replace(debug_signing, release_signing, 1)
    path.write_text(text)
    break
else:
    raise SystemExit("Could not find Android app Gradle configuration.")
PY

# Force Vosk's transitive JNA dependency to a 16 KB page-compatible version.
# A current Vosk issue reports that JNA 5.17.0 fixes libjnidispatch.so alignment;
# the release workflow also checks every packaged native library.
python3 - "$ROOT/android/build.gradle.kts" <<'PY'
from pathlib import Path
import sys

path = Path(sys.argv[1])
if not path.exists():
    raise SystemExit(f"Android root Gradle file not found: {path}")
text = path.read_text()
block = """
allprojects {
    configurations.configureEach {
        resolutionStrategy {
            force("com.alphacephei:vosk-android:0.3.75")
            force("net.java.dev.jna:jna:5.17.0@aar")
            force("net.java.dev.jna:jna:5.17.0")
        }
    }
}
"""
if "net.java.dev.jna:jna:5.17.0" not in text:
    text += block
path.write_text(text)
PY

cd "$ROOT"
flutter pub get
if [[ "$GENERATE_ICON" == true ]]; then
  dart run flutter_launcher_icons
fi

echo
echo "Android project scaffold and VoiceMate launcher icon generated."
echo "Application ID expected: com.dev.voicemate"
echo "Target SDK configured: 36"
echo "Next run: flutter analyze && flutter test && flutter run"
