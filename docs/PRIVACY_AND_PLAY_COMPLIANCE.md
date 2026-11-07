# Privacy, Permissions and Google Play Checklist

Engineering checklist only; re-check current Android and Google Play policies before release.

## Microphone disclosure
Before requesting permission, explain:

> Vokey uses your microphone to detect claps, whistles, and supported voice commands while monitoring is enabled. Audio is processed on your device and is not recorded or uploaded by Vokey. A persistent notification indicates active monitoring. You can stop monitoring at any time.

Only make this claim if the implementation and included SDKs support it. Disclose third-party advertising SDK data handling separately.

## Minimise permissions
Request only when feature implementation requires them:
- `RECORD_AUDIO` – clap, whistle and offline voice.
- `FOREGROUND_SERVICE` and `FOREGROUND_SERVICE_MICROPHONE` – applicable foreground service requirements.
- `POST_NOTIFICATIONS` – notification permission where applicable.
- `VIBRATE` – vibration.
- `CAMERA` – only if required by flashlight implementation.
- Device administrator – optional screen-lock shortcut only, with explicit activation.

Avoid contacts, location, SMS, call logs, broad storage, Accessibility, overlay, exact alarms and full-screen intent unless a separately justified feature requires them. Review merged manifest and transitive SDK permissions.

## Foreground microphone service
- Explicit user start and runtime permission.
- Correct service type and Android-version permissions.
- Accurate persistent notification while capture is active, with working Stop.
- Handle permission revocation, microphone contention, errors and resource cleanup.
- Never start secretly at boot or from an ad callback/timer.
- No guarantee after force-stop/reboot or on every OEM.
- Explain battery restrictions without coercive exemption prompts.

## Audio and local data
Audio stays local; buffers are transient. Do not write raw audio/transcripts to files, logs, analytics or crash reports. Persist settings and event metadata only. Provide history deletion. No cloud speech or audio upload.

## Firebase Analytics and Crashlytics
- Integration: `lib/services/telemetry_service.dart`. Only events in `TelemetryService.allowedEvents` are sent; parameters are sanitised to numbers/booleans and short lowercase enum strings (free text is dropped).
- Never sent: audio, recordings, transcripts, sound/file names, user-typed text, exact durations (bucketed).
- Opt-out: Settings → Privacy & data (“Share usage analytics”, “Send crash reports”). Debug builds never upload crashes.
- Firebase never blocks or crashes startup: initialised inside the protected startup path with an 8 s timeout; all calls are no-ops on failure.
- Play Data safety must declare (collected, not sold): App activity (app interactions), App info and performance (crash logs, diagnostics), Device or other IDs (Firebase app-instance ID). Purposes: analytics, app functionality/diagnostics.
- EU/UK: decide whether analytics needs prior consent (UMP form purposes or a first-run prompt) before release in those regions.

## Ads and consent
Use official Google Mobile Ads Flutter SDK and test units in development. Integrate UMP/consent choices as required. Publish accurate privacy policy and Data safety disclosures, including SDK behavior. Ads never block offline utility or appear during monitoring, alert playback, permission requests, onboarding or service start/stop. Label native ads and cap interstitial frequency conservatively.

## Screen lock
DevicePolicyManager is only a user-enabled screen-lock shortcut. Explain activation/deactivation. Never claim voice unlock or bypass PIN, pattern, password or biometrics. Do not use Accessibility to simulate secure unlock.

## Release checklist
- [ ] Target Android 16 / API 36 or higher for new app submissions from 31 August 2026.
- [ ] Accurate microphone declaration and foreground service type/permissions where applicable.
- [ ] Publish a monitored developer contact address in the store listing and privacy policy contact section.
- [ ] Host the policy at a public HTTPS URL and link it from the app and Play Console.
- [ ] Microphone disclosure before permission request.
- [ ] Public HTTPS privacy policy accurately describes microphone, flashlight, offline model, local history and Google Mobile Ads/UMP handling.
- [ ] Data safety includes the Google Mobile Ads SDK actually bundled by the release (IP address, app interactions, diagnostics and device/account identifiers may be collected/shared by the SDK; confirm the exact resolved SDK version and configuration).
- [ ] UMP refreshes consent information on every launch, any required form completes before the ad gate opens, and `canRequestAds()` is checked before every ad request.
- [ ] If UMP requires a privacy-options entry point, the Settings item remains visible and opens the form.
- [ ] Hosted and in-app privacy policies describe the included GMA/UMP SDK, the Home-only banner placement and the optional Vosk model download.
- [ ] UMP consent tested in relevant regions.
- [ ] Ad placements reviewed against current policy.
- [ ] Content rating and permissions declarations complete.
- [ ] Store copy avoids unsupported always-on/voice-unlock claims.
- [ ] Signed AAB tested on physical devices/internal track.
