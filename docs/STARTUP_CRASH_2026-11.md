# Startup crash investigation (2026-11-06)

## Symptom
Release APK closed immediately after tapping the icon, before onboarding. Debug builds worked.

## Reproduction
Fresh install of `flutter build apk --release` on the Android 16 (API 36) arm64 emulator:

```
FATAL EXCEPTION: main
java.lang.RuntimeException: Unable to get provider androidx.startup.InitializationProvider
Caused by: java.lang.RuntimeException: Failed to create an instance of androidx.work.impl.WorkDatabase
  at androidx.work.WorkManagerInitializer.create(...)
```

## Root cause (confirmed)
- `google_mobile_ads` 9.2.0 → `play-services-ads` 25.5.0 → `androidx.work:work-runtime` 2.7.0 → `androidx.room:room-runtime` 2.2.5.
- WorkManager auto-initialises through `androidx.startup.InitializationProvider` while the process binds — before `MainActivity` and before any Dart code. No Flutter-side try/catch can intercept it.
- Room 2.2.5 instantiates `WorkDatabase_Impl` reflectively with `Class.newInstance()`.
- work-runtime 2.7.0's consumer rule is `-keep class * extends androidx.room.RoomDatabase` (class only, no members). AGP 9 runs R8 in **full mode**, which does not implicitly keep the default constructor of a class kept only by name. R8's `usage.txt` listed `WorkDatabase_Impl.<init>()` as removed.
- Debug builds skip R8, which is why only release crashed.

## Fix
`android/app/proguard-rules.pro`:
```
-keep class * extends androidx.room.RoomDatabase { <init>(); }
```
plus JNA/Vosk keep rules (same reflective failure mode would have broken offline voice in release).

## Contributing process issue
`android/` was not committed; CI regenerated it with `bootstrap_android.sh` on each run, so local and CI builds were different projects. The Android project is now committed and CI builds it directly.

## Defence in depth (Dart)
- Hive init/open moved out of `main()` into `AppStartupState.initialize()`; failures render a recovery screen (Try again / Reset local data) instead of an exception before `runApp`.
- Reset deletes the settings box **by name** (`Hive.deleteFromDisk()` only deletes open boxes, which a failed open is not).
- Corrupt box files are recovered by Hive's crash recovery; wrongly typed values fall back to defaults (`lib/core/storage/safe_read.dart`).
- Diagnostics log only the failing stage and exception type — never settings values.

## Verification
| Check | Result |
|---|---|
| Release APK fresh install → onboarding (emulator API 36) | Pass |
| Complete onboarding → relaunch → Home (emulator) | Pass |
| `usage.txt` no longer lists `WorkDatabase_Impl.<init>()` | Pass |
| `test/app/startup_test.dart` (fresh, upgrade, corrupt file, bad types, init failure, reset) | Pass |
| Physical device | **Not yet run** |

## Regression guards
CI fails if R8 strips the constructor again, and runs `scripts/launch_smoke_test.sh` against the release APK on an emulator.
