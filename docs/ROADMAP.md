# Vokey Roadmap

## Phase 0 – Repository setup
- [x] Dedicated repository and product/UI/architecture/privacy documentation.
- [x] Android Gradle project committed (bootstrap regeneration retired, 2026-11-06).
- [x] Application ID `com.dev.vokey` verified in built APK (CI also checks it).

## Phase 1 – Flutter foundation
- [x] Premium dark theme and design tokens (starter theme committed).
- [x] Three-page onboarding with local completion state.
- [x] Home dashboard and four-tab navigation shell.
- [x] Settings screen with Hive-persisted alert preferences.
- [ ] Typed Hive models/adapters and migration strategy.
- [ ] Permission education screens; no microphone service yet.
- [x] Android platform project committed; application ID verified.
- [ ] Run format, analyze, widget tests and a physical-device smoke test.

Exit: navigation works, preferences persist, tests and analysis pass.

## Early clap feasibility spike (parallel)
- [x] Add Kotlin AudioRecord prototype source, started only by the visible clap-test screen.
- [x] Bridge numeric signal metrics only; no audio samples or recordings are saved by the prototype.
- [ ] Test clap versus speech, music, TV, fans, traffic and silence on physical devices.
- [ ] Measure false positives, missed detections, CPU and battery on real phones.
- [ ] Document Android background feasibility before promising always-on monitoring.

## Phase 2 – Finder engine
- [ ] Foreground microphone service and persistent Stop notification.
- [ ] Single AudioRecord owner.
- [ ] Clap/whistle algorithms.
- [ ] Alert playback, vibration and flashlight.
- [ ] MethodChannel/EventChannel lifecycle and error handling.
- [ ] Physical-device battery/resource tests.

## Phase 3 – Offline voice
- [ ] Select/license bundled offline engine and model.
- [ ] Ship and test initial language.
- [ ] Local command matching and confidence handling.
- [ ] Airplane-mode and noisy-environment tests.

## Phase 4 – Utility completion
- [ ] Alert Studio and Sound Library.
- [ ] Metadata-only History.
- [ ] Monitoring Centre and battery guidance.
- [ ] Optional DevicePolicyManager screen-lock shortcut.
- [x] Draft Privacy Policy HTML and Play Store listing checklist committed.
- [ ] Host policy publicly and add in-app policy link.
- [ ] Actual Play Store screenshots from release build.
- [ ] Offline Help.

## Phase 5 – AdMob
- [ ] Official Google Mobile Ads Flutter SDK and UMP consent.
- [ ] Test IDs in development.
- [ ] Conservative banner/native/interstitial placements.
- [ ] Confirm ads never interrupt active utility.
- [ ] Verify offline behavior.

## Phase 6 – Quality/release
- [ ] Unit, widget and integration tests.
- [ ] Airplane mode, screen-off, battery saver, revoked permission, mic contention and force-stop tests.
- [ ] Android 12/13/14/15/current supported version checks.
- [ ] Test Samsung, Xiaomi/Redmi, Realme, OnePlus and Motorola where available.
- [ ] Review merged manifest, Play declarations, Data safety and privacy.
- [ ] Signed AAB and internal/closed testing.


## Master implementation plan — status (updated 2026-11-06)

Evidence key: **E** = emulator (API 36 arm64), **U** = unit/widget test, **P** = physical device. Nothing below is marked done without the listed evidence.

### Stage 1 — Audit and startup crash ✅ (E, U)
- [x] Root cause found: R8 full mode stripped `WorkDatabase_Impl.<init>()` (WorkManager pulled in by play-services-ads) → crash in `InitializationProvider` before Flutter. Fixed in `android/app/proguard-rules.pro`. Details: `docs/STARTUP_CRASH_2026-11.md`.
- [x] Safe Hive startup, recovery screen, reset-by-name, typed-value fallbacks.
- [x] Launch tests: fresh install, upgrade with settings, corrupt box, wrong types, init failure, reset.
- [x] Kotlin unit tests wired into Gradle (18 tests).
- [x] CI: format check, R8 regression guard, package-ID check, emulator launch smoke test.
- [ ] Physical-device first-launch check (P).

### Rebrand to Vokey ✅ (E, U)
- [x] Launcher label, in-app copy, notification text, privacy policy → "Vokey". Application ID changed to `com.dev.vokey`; Kotlin package, Dart package (`vokey`), channel names and Hive box (`vokey_settings`) renamed to match. Safe only because the app was never published — old test installs are a separate app.
- [x] Text-free icon: adaptive launcher icon + 512×512 RGBA Play icon (`assets/branding/`).
- [x] Dark native launch window + Android 12 splash; animated Flutter splash; restyled 3-slide onboarding per `assets/branding/reference/vokey_ui_reference.png`.
- [ ] Supported phrases: "find my phone", "where are you", "stop listening", "lock my phone" (the old-brand "hello voice mate" was removed): "Vokey" is not in the Vosk small-model vocabulary, so "Start/Stop Vokey" from the reference board is **not** implemented.

### Stage 2 — Core monitoring reliability ⏭ NEXT (continuation point)
- [ ] Single AudioRecord owner shared by service + Finder Test (today MainActivity and the service each create an `AudioCaptureManager`, mutually guarded but not unified).
- [ ] Emergency Stop All (mic, service, alert, torch, vibration) from Home, Monitoring Centre, notification; instrumentation test with app backgrounded.
- [ ] Authoritative native state store (for tile/widget/Flutter resync after process death).
- [ ] Typed, versioned channel payloads (`schema_version`).
- [ ] Notification tap → open app; Stop action verified with UI not visible.

### Stage 3 — Detection & alerts — not started
Clap patterns (single/double/triple), whistle range/duration config, volume ramp (stream volume only, never global), Flashlight SOS duration, pocket mode, headphone route policy, Alert screen with Stop/Snooze.

### Stage 4 — Finder usability — partial (existing screens)
Finder Test Mode (extend clap diagnostic), Permission Health (extend Permission Centre: Bluetooth, sensor, FGS), battery thresholds/auto-stop, custom sounds via SAF, Alert Studio presets.

### Stage 5 — Quick Settings tile, home widget, analytics — not started
### Stage 6 — Bluetooth remote, Wear OS — not started (needs a defined BLE protocol / accessory and a Wear build target)
### Stage 7 — Full UI redesign of remaining screens per reference board — not started (splash + onboarding done)
### Stage 8 — Instrumentation tests, physical devices, signed AAB, Play review — not started

### Open questions for the product owner
- VelocityX/VxStore is a dependency but unused; existing screens use `setState`. Migrate (Stage 7) or drop the requirement?
- Offline voice downloads a 40 MB model on first use (Vosk small en-US, Apache-2.0). Bundle it in the AAB instead (≈+40 MB install) to be offline from first launch?

## Definition of done
All controls work; finder is offline; supported voice works in airplane mode; monitoring follows Android service rules with visible Stop; no raw audio is stored/uploaded; preferences/history persist; ads never gate utility; critical physical-device tests pass; store copy describes only verified behavior.

## Agent workflow
Inspect before editing → implement a vertical slice → format → analyze → test → fix → report changed files and limitations. Never claim untested features work.
