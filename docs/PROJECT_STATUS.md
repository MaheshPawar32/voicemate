# Vokey — Project Status

_Last updated: 2026-11-07 (evening) · Branch: `vokey-rebrand` · Repo: [MaheshPawar32/vokey](https://github.com/MaheshPawar32/vokey)_

**Vokey** (Voice Control & Phone Finder) is an Android-only, offline-first Flutter + Kotlin app.
App ID `com.dev.vokey` · Dart package `vokey` · Target/compile SDK 36 · Min SDK 24 · Monetization: AdMob only.

**Status key:** ✅ done and verified · 🟡 partial (works but incomplete, or built but not connected) · ⚙️ native engine done, no UI yet · ❌ not started

**Release readiness: _Buildable but unstable._** The startup crash is fixed and the main finder flow (start, listen, stop from the notification) is verified on an emulator under `com.dev.vokey`. There has been no physical-device testing (so no real clap/whistle detection yet) and there is no production signing.

---

## 1. Done

### Startup crash fix ✅
- **Symptom:** the release APK closed immediately on launch. Debug builds worked.
- **Root cause:** R8 full mode (the default in AGP 9) stripped the `WorkDatabase_Impl` constructor. WorkManager is pulled in by `play-services-ads` and initialises before Flutter starts, so the crash happened before any app code ran.
- **Fix:** keep rule in `android/app/proguard-rules.pro`, plus Vosk/JNA keep rules. Full write-up: [`STARTUP_CRASH_2026-11.md`](STARTUP_CRASH_2026-11.md).
- **Process fix:** the Android project is now committed. The old `bootstrap_android.sh` regenerated it in CI, so CI built a different project than developers did.
- **Safe startup:** a recovery screen with Try again / Reset local data, and safe defaults for corrupt or wrongly typed settings.

### Rebrand to Vokey ✅
- **Names:** app name, application ID, Kotlin package, Dart package, channel names and the Hive box renamed from VoiceMate. The GitHub repo is renamed to `vokey`.
- **Icons:** text-free adaptive launcher icon, and a **512×512 Play Store icon** at `assets/branding/vokey_play_store_icon_512.png` (32-bit PNG, about 335 KB).
- **Launch:** dark native launch window and Android 12+ splash, so there's no white flash. Then an **animated splash**: glowing logo, gradient wordmark, equalizer loader and neon waves.
- **Onboarding:** three swipeable slides styled from the reference board.

### AdMob ✅ (configuration only)
| Item | ID |
|---|---|
| App ID | `ca-app-pub-3548177810801627~3283313382` |
| Banner | `ca-app-pub-3548177810801627/1046006167` |
| Interstitial | `ca-app-pub-3548177810801627/4331691239` |
| Native | `ca-app-pub-3548177810801627/9471291092` |

- Release builds use the production IDs. Debug builds and tests use Google's test IDs (`lib/core/ads/ad_ids.dart`), and a test checks this.
- The UMP consent flow runs before any ad request.
- **Only the Home banner is placed.** No interstitial or native ad placements exist yet.

### CI (`.github/workflows/flutter_ci.yml`) 🟡
- **Checks:** Dart format, analysis, Flutter tests, Kotlin tests, debug and release APK builds, and 16 KB native-library alignment.
- **Crash guards:** an R8 regression guard (fails if the crash-causing constructor is stripped again), an application-ID check, and an **emulator launch smoke test** (`scripts/launch_smoke_test.sh`).
- **Not yet run on GitHub** since these changes.

### Finder engine, Kotlin side ⚙️ (unit-tested; mostly not wired to the UI)
- **Detection:** clap **patterns** (single/double/triple), a global **cooldown**, **30 s snooze**, continuous **0–100 sensitivity**, and a configurable **whistle frequency range and minimum duration**.
- **Alerts:** a **"Phone found" notification** with Stop alert / Snooze 30s / Stop listening buttons.
- **Stop paths:** **Emergency Stop All**, which stops the microphone, monitoring, alert sound, flashlight and vibration.
- **Pocket mode:** uses the proximity sensor and handles devices without one.
- **Battery:** a **low-battery warning** and **auto-stop at a threshold**, driven by Android's battery broadcast (no polling).
- **State:** live microphone level events, and a single status snapshot (schema v1) that the app, tile and widget all read.
- **Quick Settings tile:** shows Listening / Not listening. Tap stops monitoring, or opens the app to start it.
- **Home-screen widget:** status, active detection modes, a live timer, Stop and Open.
- **Device capabilities:** flash, proximity sensor, and audio output route (speaker / wired / Bluetooth / USB).

### Tests ✅
| Suite | Result |
|---|---|
| Dart analysis / format | Clean |
| Flutter unit and widget tests | 68 / 68 pass |
| Kotlin unit tests | 45 / 45 pass |

---

## 2. Done on 2026-11-07: app connected to the engine ✅

- **Shared monitoring state:** `MonitoringController` (plain Flutter `ChangeNotifier`) mirrors the native status, so every tab shows the same state and history is recorded whichever tab is open.
- **Start sends every saved setting:** clap pattern, sensitivity, whistle band and duration, cooldown, pocket mode, battery thresholds.
- **New theme applied app-wide**; older screens pick it up automatically.
- **Stop / Stop alert / Snooze / Stop everything** buttons in the app.
- **Finder Test uses your saved settings.**
- **Resync on resume:** if monitoring was stopped from the notification, tile or widget, the app shows the right state when reopened.
- **Verified on the emulator (Android 16, API 36):**
  - release build `com.dev.vokey` launches cleanly twice
  - Start → disclosure → microphone foreground service running → Listening screen with live timer and levels
  - Stop from the notification with the app in the background → service and microphone released → app resyncs → session saved in History
  - **Not tested:** an actual clap/whistle detection (no real sound input on the emulator)

## 3. UI: reference board vs. app

Reference: `assets/branding/reference/vokey_ui_reference.png`

| Screen | Status | Notes |
|---|---|---|
| Splash | ✅ | Animated |
| Onboarding 1–3 | ✅ | Swipe, Skip/Next, Get Started |
| Permission Setup | ✅ | After onboarding; disclosure first; granted / denied / blocked → Settings; verified on emulator |
| Home dashboard ("Ready to Find") | ✅ | New design, method toggles, banner ad only when idle |
| Monitoring active ("Listening…" + timer) | ✅ | Live timer, level bars, clap-pattern progress; verified on emulator |
| Detection alert ("Phone Found!") | ✅ | In-app screen (Stop Alert, Snooze 30s, false alarm, Stop listening) + notification; not yet triggered by a real clap |
| Bottom navigation (Home / Monitor / Tools / History / Settings) | ✅ | |
| Smart Finder | ✅ | Enable finder, methods, cooldown |
| Clap Detection (pattern, sensitivity) | ✅ | |
| Whistle Detection (sensitivity, range, duration) | ✅ | |
| Voice Commands | 🟡 | Existing screen: model download, enable, lock command. Old design |
| Alert Studio (Sound / Vibration / Flashlight tabs) | ✅ | Tabs, rising volume, output, preview / stop |
| Sound Library (search, categories, import) | ✅ | Search, All / Built-in / My sounds, import, rename, delete, restore default |
| Finder Test Mode | 🟡 | Uses saved settings now. Still needs alert/flash/vibration tests and new design |
| Permission Health | 🟡 | Existing: microphone, notifications, camera, open settings. Missing: sensor, Bluetooth, foreground service |
| Monitoring Centre | ✅ | Duration, methods, service, battery, output route, pocket, schedule, Stop everything; spacing increased |
| Battery Centre | ✅ | Level, charging, warning and auto-stop thresholds; device details screen kept |
| Audio Output / Headphone policy | ✅ | Auto / Speaker / Headphones (in Alert Studio); Headphones-only silence verified on emulator |
| Pocket Mode | ✅ | Detects missing sensor |
| Detection Analytics | ✅ | Overview / Daily / Weekly, false alarms, monitoring time |
| History (filters, day groups) | ✅ | Filters, Today/Yesterday groups, retention, clear with confirmation |
| Settings (grouped) | 🟡 | Existing; old design |
| Privacy Policy / Help / About | ✅ | Existing screens |
| Voice Screen Lock | ✅ | Lock only; now has in-app “Turn off” (needed before uninstall) |
| Quick Settings tile | ⚙️ | Built; not tested on a device |
| Home-screen widget | ⚙️ | Built; not tested on a device |
| Bluetooth remote | ❌ | |
| Wear OS companion | ❌ | |

---

## 4. Features

### Core finder
| Feature | Status | Notes |
|---|---|---|
| Start/Stop monitoring with foreground notification | ✅ | Notification has Stop; tap opens the app |
| Clap detection | ✅ | Single/double/triple patterns |
| Whistle detection | ✅ | Range and duration configurable |
| Offline voice commands (Vosk, English) | 🟡 | Works after a one-time 40 MB model download. "Start/Stop Vokey" not possible: "Vokey" isn't in the model's vocabulary |
| Sound alerts | ✅ | 4 built-in tones + imported sounds, rising volume, output choice |
| Vibration alerts | ✅ | |
| Flashlight alerts | ✅ | Single, double and SOS patterns |
| Sensitivity | ✅ | 0–100 sliders |
| Cooldown | ✅ | |
| Quiet hours, auto-stop timer | ✅ | |
| History (metadata only, no audio) | ✅ | Filters, retention, false-alarm feedback |
| Screen lock shortcut (Device Admin) | ✅ | Lock only |

### Roadmap features (14)
| # | Feature | Priority | Status |
|---|---|---|---|
| 1 | Flashlight SOS | P0 | 🟡 Pattern done; configurable duration pending |
| 2 | Increasing alert volume | P0 | ✅ New alarm-stream player; ramp verified on emulator (-12 → -6 dB); device volume never changed |
| 3 | Pocket mode | P0 | ✅ (sensor behaviour untested on real phones) |
| 4 | Finder Test Mode | P0 | 🟡 |
| 5 | Permission Health Check | P0 | 🟡 Permission Setup done; Permission Health screen still old |
| 6 | Custom sounds (import, rename, delete) | P0 | ✅ Android file picker, no storage permission; import + playback verified on emulator |
| 7 | Battery-aware monitoring | P0 | ✅ |
| 8 | Headphone detection / output policy | P0 | ✅ Auto / Speaker / Headphones-only, re-checked when headphones change (real headphones not yet tested) |
| 9 | Emergency Stop All | P0 | ✅ Notification Stop verified with app in background; in-app Stop everything added |
| 10 | Quick Settings tile | P1 | ⚙️ |
| 11 | Home-screen widget | P1 | ⚙️ |
| 12 | Detection analytics | P1 | ✅ |
| 13 | Bluetooth remote | P2 | ❌ Needs a chosen accessory/protocol |
| 14 | Wear OS companion | P2 | ❌ |

---

## 5. Pending, in order

1. **Test on a physical phone:** real clap / whistle / voice detection → Phone Found → Stop / Snooze; Quick Settings tile; widget; real wired/Bluetooth headphones with each output setting.
2. **Permission Health redesign** (proximity sensor, foreground service, Bluetooth rows).
3. **Finder Test redesign** with alert, flashlight and vibration tests.
4. **Restyle the remaining old screens:** Settings groups, Voice Commands header, Privacy/Help.
5. **Ads:** interstitial at natural transitions only; native ad on an informational screen.
6. **Bluetooth remote and Wear OS** (need product decisions).
7. **Release:** instrumentation tests, physical devices, signed AAB, Play Console.

## 6. Release blockers

- [x] Release build and launch check under `com.dev.vokey` (emulator, 2026-11-07).
- [ ] Physical-device testing: Samsung, Xiaomi/Redmi, OnePlus, Motorola, Pixel.
- [ ] Production signing (`android/key.properties` + keystore, or CI secrets).
- [ ] Privacy policy hosted at `https://maheshpawar32.github.io/vokey/privacy_policy.html`. Turn on GitHub Pages and replace `REPLACE_WITH_SUPPORT_EMAIL`.
- [ ] `app-ads.txt` on the developer website.
- [ ] AdMob consent messages (GDPR / US states).
- [ ] Play Data safety form, including the Google Mobile Ads SDK.
- [ ] Microphone and foreground-service declarations in Play Console.
- [ ] Real screenshots from the built app. The reference board is a mockup and must not be used as store screenshots.
- [ ] CI green on GitHub.

---

## 7. Android limits (by design)

- **Starting:** monitoring starts only from a visible app screen. The tile, widget, watch or Bluetooth button can **stop** it or **open** the app, but can't silently start the microphone.
- **Phone Found while closed:** shown as a notification. Android blocks opening a full screen from the background without special permissions.
- **Restarts:** monitoring doesn't restart after force-stop or reboot, and background behaviour varies by manufacturer.
- **Audio routes:** reported differently by different manufacturers; shown as "reported by Android".
- **Privacy:** audio is never recorded, saved or uploaded. History stores event metadata only.

---

## 8. Open decisions

1. **VelocityX / VxStore:** the spec requires it, but no screen uses it. Migrate during the redesign, or drop the requirement?
2. **Offline voice model:** download on first use (current, 40 MB), or bundle it in the app (about 40 MB larger install, works offline from first launch)?
3. **Bluetooth remote:** which accessory or protocol to support?
4. **Wear OS:** in scope for v1?
5. **Merge `vokey-rebrand` into `main`?**
