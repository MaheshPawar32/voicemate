# Android manifest requirements for the clap test

Merge the following permission and optional hardware feature into the generated
`android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.RECORD_AUDIO" />
<uses-feature
    android:name="android.hardware.microphone"
    android:required="false" />
```

This first prototype is a foreground Activity test only. It does not use a
microphone foreground service, does not request notification permission, and
must not be treated as an always-on finder. Capture stops when the Activity
pauses or the test screen is closed.

The Android platform directory is not yet present in this repository. Generate
the official Flutter Android scaffold from the project root first:

```bash
flutter create --platforms=android --org com.dev .
```

Then verify the generated namespace and application ID are both
`com.dev.voicemate`. Keep native sources in
`android/app/src/main/kotlin/com/dev/voicemate/`.
