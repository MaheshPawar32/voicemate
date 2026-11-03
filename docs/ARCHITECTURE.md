# VoiceMate Architecture

## System
```text
Flutter UI (VelocityX + Material)
  ├── Feature screens and widgets
  ├── VxStore state
  ├── Services/repositories
  └── Hive local persistence
       │ MethodChannel: commands/config
       │ EventChannel: service/detection state
       ▼
Kotlin Android layer
  ├── VoiceMonitoringService
  ├── AudioCaptureManager (single AudioRecord owner)
  ├── ClapDetector
  ├── WhistleDetector
  ├── OfflineCommandEngine
  ├── AlertManager
  ├── FlashlightManager
  ├── VibrationManager
  ├── MonitoringNotification
  └── DeviceLockManager (optional)
```

## Flutter structure
```text
lib/
  main.dart
  app/
  core/{storage,permissions,notifications,ads,platform,errors,widgets}/
  features/{onboarding,home,finder,clap_detection,whistle_detection,voice_commands,voice_lock,alert_studio,sound_library,monitoring,history,battery_centre,settings,privacy,help}/
  models/
  services/
  stores/
```
Use VelocityX/VxStore; do not add Riverpod, Provider, GetX or BLoC without an explicit decision. Keep detection algorithms outside widgets.

## Kotlin package
`android/app/src/main/kotlin/com/dev/voicemate/`
- MainActivity.kt – channel registration/lifecycle
- VoiceMonitoringService.kt – foreground service
- AudioCaptureManager.kt – sole AudioRecord owner
- ClapDetector.kt and WhistleDetector.kt – signal processing
- OfflineCommandEngine.kt – bundled speech engine
- AlertManager.kt, FlashlightManager.kt, VibrationManager.kt
- MonitoringNotification.kt – persistent notification with Stop
- DeviceLockManager.kt – optional screen lock

## Channel contract proposal
Methods: `startMonitoring(config)`, `stopMonitoring()`, `getMonitoringStatus()`, `updateDetectionConfig(config)`, `playFinderAlert(config)`, `stopFinderAlert()`, and optional `requestScreenLock()`.

Events: `service_started`, `service_stopped`, `detection`, `service_error`. Payloads contain event type/timestamp/non-sensitive metadata only—never audio samples or transcripts.

## Detection design
**Clap:** short frames, supported sample rate, RMS/energy, adaptive noise floor, transient peak and duration/spectral checks, pattern grouping, refractory period and cooldown. 16 kHz is only a candidate; verify device support and tune on hardware.

**Whistle:** FFT/STFT or equivalent spectral analysis; dominant frequency, peak prominence, harmonics, stability, duration, confidence and cooldown. Test speech, music, TV, alarms and environmental noise.

**Offline speech:** bundled licensed on-device model; verify language availability; local intent matching and confidence thresholds; no cloud fallback.

## Foreground microphone service
Start only after explicit user action and permission. Declare microphone foreground-service type and version-specific permissions. Call startForeground promptly with accurate persistent notification and working Stop action. Release AudioRecord deterministically. Respect Android background-start restrictions. Never start secretly at boot, from timers or ad callbacks. Do not promise restart after force-stop/reboot or universal OEM behavior. Do not automatically request battery exemption.

## Privacy and ads
Hive stores preferences and event metadata only. Audio buffers remain transient. Ads are isolated from monitoring lifecycle and are never required for offline operation.


## Foreground clap-test prototype

The repository includes an early diagnostic-only microphone path:
- Flutter screen: `ClapTestScreen`
- Dart bridge: `ClapTestService`
- Native channel: `com.dev.voicemate/audio_test/methods` and `com.dev.voicemate/audio_test/events`
- Kotlin capture owner: `AudioCaptureManager`
- Pure signal detector: `ClapDetector`

This is not the production monitoring service. It starts only after a visible user tap and runtime microphone permission, runs only while the Android Activity remains resumed, and stops on Activity pause or screen disposal. Only numeric RMS/peak/noise-floor/count metadata crosses the bridge. Raw PCM remains in memory and is not written to storage. The thresholds are provisional and require physical-device validation.
