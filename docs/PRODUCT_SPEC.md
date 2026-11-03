# VoiceMate Product Specification

## Identity
- Product: VoiceMate – Voice Control & Phone Finder
- Tagline: Your phone listens. Your phone responds.
- Android application ID: `com.dev.voicemate`
- Stack: Flutter + Kotlin
- Monetization: AdMob only; no subscription or IAP
- Offline-first; no account or backend

## Product promise
When the user explicitly enables monitoring, VoiceMate is intended to detect configured clap/whistle patterns and play a selected alert to help locate a misplaced phone. Supported voice commands will use an on-device model. Android background microphone restrictions and device/OEM limitations must be clearly explained.

## Modules
1. **Smart Phone Finder:** explicit start/stop; clap, whistle and supported voice triggers; sound, vibration and optional flashlight.
2. **Clap Detection:** sensitivity, single/double/triple patterns, adaptive noise floor, transient detection, cooldown and false-positive filtering.
3. **Whistle Detection:** sensitivity, frequency range, minimum duration, spectral peak/harmonic checks and cooldown.
4. **Offline Voice Commands:** bundled offline engine; local phrase/intent matching; tested language list; no cloud fallback.
5. **Optional Screen Lock:** DevicePolicyManager screen-lock shortcut only after explicit administrator activation. Never voice-unlock or bypass PIN, pattern, password or biometrics.
6. **Alert Studio:** original/licensed sounds, volume, duration, repeat, vibration and flashlight pattern.
7. **Monitoring Centre:** service state, persistent notification Stop action, permission state and battery guidance.
8. **History:** event metadata and timestamps only; no audio/transcripts; clear-history action.
9. **Battery & Performance:** practical controls and guidance; no fabricated estimates or unnecessary wake locks.
10. **Privacy Centre:** permissions, local data explanation, privacy policy and deletion controls.

## Screen inventory
Splash; onboarding (finder, voice control, privacy); Home dashboard; Smart Finder; Clap Detection; Whistle Detection; Offline Voice Commands; Voice Screen Lock; Alert Studio; Sound Library; Monitoring Centre; History; Battery & Performance; Settings; Permissions Centre; offline Privacy Policy; About & Help.

Every applicable screen needs loading, empty, denied-permission, unsupported-device and error states.

## Local data (Hive; snake_case fields)
- AppSettings: `theme_mode`, `language_code`, `sound_enabled`, `vibration_enabled`, `flashlight_enabled`
- DetectionSettings: `clap_enabled`, `whistle_enabled`, `voice_enabled`, `clap_sensitivity`, `whistle_sensitivity`, `cooldown_seconds`, `detection_mode`
- MonitoringSettings: `monitoring_enabled`, `notification_enabled`, `auto_stop_minutes`, `quiet_hours_enabled`, `quiet_start`, `quiet_end`
- AlertSettings: `sound_id`, `volume`, `repeat_enabled`, `flash_pattern`, `vibration_pattern`, `alert_duration`
- HistoryEvent: `id`, `event_type`, `timestamp`, `metadata`

Never persist microphone buffers, raw audio or transcripts.

## UI direction
Premium dark utility UI. Background `#0B1020`, surface `#131B2E`, card `#19243A`, cyan `#26D9E8`, violet `#7777FF`, primary text `#F4F7FF`, secondary text `#9BA9BE`. Use restrained gradients, clear hierarchy, accessible controls and subtle motion. Avoid excessive glass effects.

## Advertising rules
Official Google Mobile Ads Flutter SDK. Banners on low-interruption informational screens; labelled native ads in Discover; conservative interstitials only at natural transitions. Never show ads during monitoring, alert playback, onboarding, permission requests or service start/stop. Rewarded ads may unlock cosmetic themes only. Offline ads must never block utility.
