# VoiceMate Roadmap

## Phase 0 – Repository setup
- [x] Dedicated repository and product/UI/architecture/privacy documentation.
- [ ] Generate/validate Android Flutter project using `bootstrap_android.sh`.
- [ ] Verify application ID `com.dev.voicemate`.

## Phase 1 – Flutter foundation
- [x] Premium dark theme and design tokens (starter theme committed).
- [x] Three-page onboarding with local completion state.
- [x] Home dashboard and four-tab navigation shell.
- [x] Settings screen with Hive-persisted alert preferences.
- [ ] Typed Hive models/adapters and migration strategy.
- [ ] Permission education screens; no microphone service yet.
- [ ] Generate Android platform scaffold and verify application ID.
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
- [ ] Bundled Privacy Policy and offline Help.

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

## Definition of done
All controls work; finder is offline; supported voice works in airplane mode; monitoring follows Android service rules with visible Stop; no raw audio is stored/uploaded; preferences/history persist; ads never gate utility; critical physical-device tests pass; store copy describes only verified behavior.

## Agent workflow
Inspect before editing → implement a vertical slice → format → analyze → test → fix → report changed files and limitations. Never claim untested features work.
