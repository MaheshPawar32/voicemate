# Privacy, Permissions and Google Play Checklist

Engineering checklist only; re-check current Android and Google Play policies before release.

## Microphone disclosure
Before requesting permission, explain:

> VoiceMate uses your microphone to detect claps, whistles, and supported voice commands while monitoring is enabled. Audio is processed on your device and is not recorded or uploaded by VoiceMate. A persistent notification indicates active monitoring. You can stop monitoring at any time.

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

## Ads and consent
Use official Google Mobile Ads Flutter SDK and test units in development. Integrate UMP/consent choices as required. Publish accurate privacy policy and Data safety disclosures, including SDK behavior. Ads never block offline utility or appear during monitoring, alert playback, permission requests, onboarding or service start/stop. Label native ads and cap interstitial frequency conservatively.

## Screen lock
DevicePolicyManager is only a user-enabled screen-lock shortcut. Explain activation/deactivation. Never claim voice unlock or bypass PIN, pattern, password or biometrics. Do not use Accessibility to simulate secure unlock.

## Release checklist
- [ ] Target Android 16 / API 36 or higher for new app submissions from 31 August 2026.
- [ ] Accurate microphone declaration and foreground service type/permissions where applicable.
- [ ] Replace the support-email placeholder in `privacy_policy.html`.
- [ ] Host the policy at a public HTTPS URL and link it from the app and Play Console.
- [ ] Microphone disclosure before permission request.
- [ ] Public accurate privacy policy.
- [ ] Data safety includes SDK data handling (the Google Mobile Ads SDK automatically collects/shares IP address, app interactions, diagnostics and device/account identifiers; confirm the actual SDK version/configuration).
- [ ] UMP consent tested in relevant regions.
- [ ] Ad placements reviewed against current policy.
- [ ] Content rating and permissions declarations complete.
- [ ] Store copy avoids unsupported always-on/voice-unlock claims.
- [ ] Signed AAB tested on physical devices/internal track.
