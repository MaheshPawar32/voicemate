# VoiceMate Roadmap

## Product principles
- Android-first, offline-first and user-controlled.
- Microphone monitoring starts only after an explicit in-app action and runtime permission, runs as a correctly declared foreground service, and always exposes a working Stop action.
- No hidden listening, no raw audio/transcript storage, no cloud audio upload, and no automatic microphone restart from a widget, tile, Bluetooth accessory, boot receiver or ad callback.
- External controls may request a visible, policy-compliant action; they must not bypass Android background-start or permission rules.
- Keep the existing Flutter + Kotlin architecture, VelocityX/VxStore state approach and Hive local persistence. Do not add another state-management framework without an explicit decision.
- A feature is complete only after automated tests and relevant Android-device validation. UI presence alone is not completion.

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

## Phase 2 – Core finder engine and reliability (P0)
Deliver the core user-controlled finder before companion integrations.

- [ ] Production foreground microphone service, persistent notification and notification Stop action.
- [ ] Single AudioRecord owner with deterministic start/stop/error recovery.
- [ ] Clap and whistle detection algorithms, pattern grouping, cooldown and configurable sensitivity.
- [ ] Alert playback, vibration and flashlight controls.
- [ ] **Emergency stop:** stop monitoring and alert playback from the app and persistent notification; make Stop available even when the app UI is not open. Verify notification action works on supported Android versions.
- [ ] **Finder test mode:** a clearly labelled, foreground-only calibration flow that displays input level and detector feedback, lets the user test each trigger and alert, and never claims background monitoring is active.
- [ ] **Increasing alert volume:** optional gradual ramp using the app's alert audio stream, configurable ramp/duration and a hard user-selected maximum. Do not silently change the user's global media volume; handle audio focus, DND and connected output honestly.
- [ ] **Flashlight SOS:** selectable steady, pulse and SOS patterns, with capability checks, thermal/battery safeguards, lifecycle cancellation and an immediate stop control.
- [ ] **Pocket mode:** optional proximity-sensor guard to suppress accidental interaction/triggering while covered; provide a setting to disable it and a fallback on devices without a usable proximity sensor.
- [ ] **Headphone detection:** observe audio-device route changes and warn or apply a user-selected safe output policy when headphones/Bluetooth audio are connected. Do not assume every OEM reports every route identically.
- [ ] **Battery-aware monitoring:** show battery level/charging state, warn at a configurable low threshold and optionally stop monitoring at a user-selected threshold. Do not promise precise per-feature battery estimates or silently request battery-optimization exemptions.
- [ ] **Permission health check:** central status screen for microphone, notifications, flashlight/camera capability and sensor/device support; explain how to restore access after revocation and re-check on app resume.
- [ ] **Custom sounds:** import user-selected audio through Android Storage Access Framework, preview, validate supported formats/duration, copy only the selected sound into app-private storage, and offer delete/reset controls.
- [ ] MethodChannel/EventChannel lifecycle, typed errors and service-state reconciliation.
- [ ] Physical-device battery/resource and detection reliability tests.

Exit: user can explicitly start/stop monitoring, find the phone with verified triggers, stop all outputs immediately, and understand permission/battery/device limitations.

## Phase 3 – Offline voice
- [ ] Select/license bundled offline engine and model.
- [ ] Ship and test initial language.
- [ ] Local command matching and confidence handling.
- [ ] Airplane-mode and noisy-environment tests.

## Phase 4 – Everyday controls and insight (P1)
- [ ] **Quick Settings tile:** implement Android `TileService` with accurate inactive/active/unavailable states. Tile can open the app or request a permitted user-visible start/stop flow; never silently start microphone capture from a background tile tap where Android requires an Activity or foreground-service start.
- [ ] **Home screen widget:** native Android AppWidget (or a compatible Flutter widget bridge) showing monitoring state and offering app-open/stop actions. Keep state synchronized with the service; do not use widget refresh as a polling loop or hidden microphone start mechanism.
- [ ] **Detection analytics:** local-only summaries such as event counts by type, time range, false-trigger feedback and monitoring duration. Store metadata only; provide clear/export controls and retention settings. No audio, voice transcripts or sensitive content.
- [ ] **Custom sound profiles:** save named combinations of trigger, sound, volume cap, vibration and flashlight preferences once the base custom-sound feature is stable.
- [ ] Offline Help, troubleshooting and device compatibility explanations.
- [ ] Accessibility review for text scaling, contrast, TalkBack, touch targets and reduced motion.

Exit: external controls always reflect the true service state; analytics are transparent, local and deletable.

## Phase 5 – Companion integrations (P2)
These are separate integrations and should begin only after the core service contract is stable.

- [ ] **Bluetooth remote:** define supported accessory/protocol first (for example, a paired BLE button). Use Android Companion Device Manager where suitable; otherwise request only the Bluetooth permissions required by the selected discovery/connection path. Authenticate and allow-list paired devices, debounce button events, expose connection status, and let the user revoke/unpair. Remote may request a safe action but cannot bypass microphone permission, user consent or foreground-service restrictions.
- [ ] **Wear OS companion:** create a separate Wear OS module/app with a minimal status and control UI. Use Wearable Data Layer for supported paired-device communication, secure message validation, connection/offline states and explicit confirmation where needed. Watch controls should open/hand off to a compliant phone-side flow; do not promise remote microphone start when Android disallows it.
- [ ] Companion pairing, disconnect, lost-connection, duplicate-event and stale-state tests.
- [ ] Document supported watch/phone and accessory combinations before listing compatibility.

Exit: pairing is explicit and revocable; companion controls are reliable but never bypass phone-side Android restrictions.

## Phase 6 – Utility completion and privacy
- [ ] Alert Studio and Sound Library.
- [ ] Metadata-only History.
- [ ] Monitoring Centre and battery guidance.
- [ ] Optional DevicePolicyManager screen-lock shortcut, only after explicit device-admin activation; never voice-unlock or bypass device credentials.
- [x] Draft Privacy Policy HTML and Play Store listing checklist committed.
- [ ] Host policy publicly and add in-app policy link.
- [ ] Actual Play Store screenshots from release build.
- [ ] Offline Help.
- [ ] Review custom audio import, local analytics retention and companion-device data disclosures.

## Phase 7 – AdMob
- [ ] Official Google Mobile Ads Flutter SDK and UMP consent.
- [ ] Test IDs in development.
- [ ] Conservative banner/native/interstitial placements.
- [ ] Confirm ads never interrupt active utility.
- [ ] Verify offline behavior.

## Phase 8 – Quality and release
- [ ] Unit, widget and integration tests.
- [ ] Android instrumentation tests for foreground service, notification Stop, tile, widget, audio routes, sensor absence and permission revocation.
- [ ] Airplane mode, screen-off, battery saver, mic contention and force-stop tests.
- [ ] Android 12/13/14/15/current supported version checks.
- [ ] Test Samsung, Xiaomi/Redmi, Realme, OnePlus and Motorola where available.
- [ ] Review merged manifest, foreground-service declarations, Play declarations, Data safety and privacy.
- [ ] Signed AAB and internal/closed testing.
- [ ] Verify release behavior on representative physical devices before claiming production readiness.

## Android feasibility and permission notes

| Feature | Android implementation / feasibility | Permission and platform notes |
|---|---|---|
| Flashlight SOS | `CameraManager.setTorchMode`; feasible on devices with a flash unit | Check camera/torch availability; request CAMERA only if required by the selected API/device path. Handle camera-in-use and thermal failures. |
| Increasing alert volume | App-owned alert playback with a controlled ramp | Usually no special runtime permission; audio focus and DND/output routing still apply. Do not change global volume without clear user intent. |
| Pocket mode | Proximity sensor via `SensorManager` | No runtime permission for standard sensor access. Sensor may be absent or unreliable on some devices. |
| Finder test mode | Visible Activity + detector diagnostic stream | RECORD_AUDIO runtime permission; test screen must clearly show when microphone is active and stop on exit. |
| Permission health check | Permission APIs, app-op/service state and capability checks | No extra permission merely to inspect this app's grants. Re-check after returning from Settings. |
| Custom sounds | Android Storage Access Framework document picker; app-private copy | No broad storage permission when using the system picker. Validate size, duration, codec and file errors. |
| Quick Settings tile | Android `TileService` | No special runtime permission for tile itself. Microphone start remains subject to foreground-service and background-start rules. |
| Battery-aware monitoring | `BatteryManager` and battery status broadcasts | No special runtime permission for basic battery state. Thresholds are user-configurable; readings are not precise usage attribution. |
| Headphone detection | `AudioManager` / `AudioDeviceCallback` | Usually no runtime permission. Test wired, USB, Bluetooth and OEM-specific routing. |
| Emergency stop | Foreground notification action + app control | Notification permission on Android 13+ affects notification visibility; foreground-service notification rules still apply. Stop action must remain accessible. |
| Home screen widget | Android AppWidget provider / Glance integration | No dangerous runtime permission for basic widget. Use explicit PendingIntent and avoid background polling. |
| Wear OS companion | Wear OS app + Wearable Data Layer | Requires compatible watch/app pairing and connection. No phone permission should be requested until a specific feature needs it. |
| Detection analytics | Local aggregation in Hive/app-private storage | No additional permission. Store event metadata only; add retention and clear-data controls. |
| Bluetooth remote | BLE/GATT or supported companion-device pairing | Android 12+ may require BLUETOOTH_SCAN and/or BLUETOOTH_CONNECT; older versions may require location for scanning. Prefer Companion Device Manager when it fits. Exact permissions depend on protocol and target SDK. |

## Architecture additions (planned)

Flutter feature modules:
- `features/finder_test/` – visible calibration and test flow.
- `features/permission_centre/` – permission/capability status and recovery guidance.
- `features/analytics/` – local metadata summaries and retention controls.
- `features/companion/` – pairing state and companion settings.
- Extend `alert_studio/`, `sound_library/`, `monitoring/` and `battery_centre/` for the P0 work.

Kotlin responsibilities:
- `AlertManager` – app-owned playback, volume ramp, audio focus and stop.
- `FlashlightManager` – torch capability, patterns, cancellation and error state.
- `PocketModeManager` – proximity sensor lifecycle and debounce.
- `AudioRouteMonitor` – headphone/Bluetooth route changes.
- `BatteryStateMonitor` – battery level/charging signals and configured thresholds.
- `PermissionStatusProvider` – native capability/service status where Flutter permission APIs are insufficient.
- `MonitoringTileService` – Quick Settings state/actions.
- `VoiceMateAppWidgetProvider` – widget state/actions.
- `BluetoothRemoteManager` – explicitly paired accessory connection and authenticated button events.
- Wear OS companion module – status/control messages; phone remains authoritative for monitoring lifecycle.

Channel contract additions (proposed; keep payloads typed and versioned):
- Methods: `getCapabilityStatus()`, `getBatteryStatus()`, `setAlertProfile(config)`, `previewAlert(config)`, `stopAllOutputs()`, `getAudioRouteStatus()`, `pairRemote()`, `disconnectRemote()`.
- Events: `capability_changed`, `battery_changed`, `audio_route_changed`, `remote_connected`, `remote_disconnected`, `remote_action`.
- Continue existing `service_started`, `service_stopped`, `detection`, `service_error` events.
- External surfaces must invoke the same service/repository actions as the Flutter app and reconcile from authoritative native service state.
- Never pass raw PCM, transcripts, access tokens or unnecessary device identifiers across channels.

## Data model additions (proposed; snake_case)
- `AlertProfile`: `id`, `name`, `sound_id`, `volume_cap`, `volume_ramp_enabled`, `volume_ramp_seconds`, `vibration_pattern`, `flash_pattern`.
- `FinderPreferences`: `pocket_mode_enabled`, `headphone_policy`, `battery_stop_threshold`, `battery_warning_threshold`, `flashlight_sos_enabled`.
- `DetectionAnalytics`: aggregate counters and date buckets only; no audio/transcript fields.
- `PairedRemote`: minimum required pairing metadata and user-visible display name; no unnecessary tracking.
- Keep schema migrations backward-compatible with existing Hive settings.

## Test and acceptance checklist for the new features
- Emergency Stop stops microphone capture, alert audio, vibration and flashlight from every supported surface.
- Finder test mode cannot be mistaken for background monitoring and releases microphone resources on every exit/error path.
- Volume ramp respects the configured cap, audio focus, route changes and explicit stop.
- Flashlight pattern cancels on stop, app/service teardown, unavailable camera and torch errors.
- Pocket mode behaves safely when the sensor is absent, covered or noisy.
- Headphone policy is predictable across wired, USB and Bluetooth route changes.
- Battery warnings/auto-stop use configured thresholds and never claim exact battery savings.
- Permission screen accurately reflects revoked/denied permissions and does not repeatedly prompt.
- Imported sounds survive app restart, reject invalid files and can be deleted.
- Tile and widget show authoritative service state, handle stale intents and cannot silently start listening.
- Analytics contains only local event metadata and is fully clearable.
- Bluetooth remote and Wear OS pairing are explicit, revocable, authenticated and tested through disconnect/reconnect.
- Test Android version-specific permission behavior and OEM restrictions; document unsupported combinations.

## Definition of done
All controls work; finder is offline; supported voice works in airplane mode; monitoring follows Android service rules with visible Stop; no raw audio is stored/uploaded; preferences/history persist; analytics are metadata-only and deletable; companion actions do not bypass Android restrictions; ads never gate utility; critical automated and physical-device tests pass; store copy describes only verified behavior.

## Agent workflow
Inspect before editing → implement a vertical slice → format → analyze → test → fix → report changed files and limitations. Never claim untested features work.
