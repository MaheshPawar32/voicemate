# Clap detection prototype – setup and test

## 1. Generate the Android project

From the repository root on a machine with Flutter and Android SDK installed:

```bash
chmod +x bootstrap_android.sh
./bootstrap_android.sh
```

This uses Flutter's generator to create the Android Gradle project and wrapper, then restores the Vokey Kotlin sources and adds the microphone permission.

## 2. Run static checks

```bash
flutter analyze
flutter test
flutter run
```

The Android application ID should be `com.dev.vokey`.

## 3. Start the diagnostic test

On the phone, open **Clap Detection Lab** from the Home quick tools. Read the disclosure and tap **Start clap test**. Grant microphone permission when Android asks. The detector runs only while the test is active and the Android Activity remains in the foreground.

Tap **Stop test** or leave the app to stop capture. The native Activity also stops capture from `onPause`.

## 4. Test in real environments

Try at least:
- Quiet room: 20 single claps at close, medium and far distances.
- Speech: normal conversation and loud talking.
- Music/TV: different volume levels.
- Household noise: fan, air conditioner, keyboard and door knocks.
- Outdoor noise: traffic and public-space ambience.
- Repeated patterns: single, double and triple claps at different intervals.

Record manually:
- Number of intentional claps.
- Number detected.
- False detections during a 10-minute non-clap period.
- Approximate distance, phone placement and room conditions.
- Device model and Android version.

Do not store or upload raw audio for this experiment. Numeric metrics shown in the app are transient signal measurements.

## Limitations

- This is a feasibility prototype, not production phone-finder monitoring.
- Thresholds are provisional and not calibrated across microphones.
- No background microphone foreground service exists yet.
- No guarantee is made for pocket/bag use, screen-off behavior, or detection through cases/obstructions.
- Android's emulator is not a valid microphone-acoustic test target; use a physical device. See [Android audio capture guidance](https://developer.android.com/media/platform/mediarecorder).

The test should not progress to a persistent foreground microphone service until false-positive and missed-detection rates are measured on multiple physical devices.
