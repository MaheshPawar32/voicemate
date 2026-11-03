# VoiceMate – Google Play Store preparation pack

**Package:** `com.dev.voicemate`  
**Platform:** Android  
**Proposed category:** Tools  
**Current repository status:** early prototype; not ready for public release.

> Complete all `REPLACE_...` fields, confirm the final feature set and audit the exact SDK/manifest before submitting. Do not publish claims for unfinished features.

## Store listing fields

### App name (23/30 characters)
`VoiceMate: Phone Finder`

### Short description (69 characters)
`Find your phone nearby with clap, whistle and offline voice controls.`

### Full description – draft for the completed release

Misplaced your phone nearby? VoiceMate is designed to help you find it with sound-triggered alerts and simple offline controls.

**FIND YOUR PHONE**
- Clap detection: use a supported clap pattern to trigger a finder alert.
- Whistle detection: activate an alert with a supported whistle.
- Offline voice commands: use supported commands processed on your device.

**MAKE IT YOURS**
- Choose an alert sound and adjust alert preferences.
- Use vibration and flashlight alerts on supported devices.
- Review recent finder events locally.

**PRIVACY-FOCUSED DESIGN**
- No account or sign-up required.
- Microphone access is requested when you choose a microphone feature.
- Audio is analysed on your device and is not saved as a recording by VoiceMate.
- Active background monitoring, when available, is shown by an ongoing Android notification with a Stop action.
- Core finder features are designed to work offline. Advertising requires an internet connection.

**IMPORTANT**
Detection depends on your phone microphone, Android version, device settings, phone placement and surrounding noise. VoiceMate cannot find a device that is powered off, outside microphone range, or unable to capture sound. Availability of individual features depends on the app version and supported device capabilities.

**Release gate:** This full description is for the intended completed app. Do not use it until clap/whistle detection, offline voice commands, alerts, local history and background monitoring are implemented, tested and supported by the actual release. For the present prototype, describe it honestly as an early foreground clap-detection test app.

### Category and tags
- Category: `Tools`
- Tags: choose only available tags that accurately describe the shipped app.

### Contact details
- Support email (required): `REPLACE_WITH_SUPPORT_EMAIL`
- Website: optional; add a real support/privacy website if available.
- Phone: optional; only add a monitored number.

### Store graphic assets
- App icon: `assets/branding/voicemate_icon_512.png` (512×512 PNG, alpha, under 1 MB).
- Feature graphic: `assets/branding/voicemate_feature_graphic_1024x500.png` (1024×500 RGB PNG, no alpha).
- Images in `store_previews/` are **design mockups only**, not captured app screenshots. Do not upload them as real experience screenshots. Capture at least 2 genuine phone screenshots from the release build; aim for 4 portrait screenshots at 1080×1920 for stronger store presentation.
- Suggested screenshot order once captured: Home, Clap Detection, Whistle/Voice features, Settings/Privacy.
- No preview video is required for the initial listing.

Suggested alt text:
1. `VoiceMate home screen showing finder status and quick tools.`
2. `Clap detection test screen showing the microphone level and detection count.`
3. `VoiceMate settings screen showing sound, vibration, flashlight and privacy options.`

## App content declarations

| Play Console area | Proposed answer / action |
|---|---|
| Ads | **Yes** once Google Mobile Ads/AdMob is included. Do not answer No if an ad SDK is shipped or ads can be requested. |
| App access | No login or special access. Reviewer note: “Open the app, complete onboarding, then open Home → Clap Detection Lab. Grant microphone permission when prompted to test.” |
| Target audience | Not designed for children. Select only age groups matching the finished app and ad configuration. If using 18+ only, ensure the app is genuinely not directed to children. |
| Content rating | Complete the IARC questionnaire based on the shipped app and ads. Play Console will assign the rating. |
| Data safety | Complete using the exact Google Mobile Ads SDK version, UMP setup, manifest and runtime behaviour. See below. |
| Privacy policy | Add a publicly accessible HTTPS webpage and a link or text inside the app. Replace the support-email placeholder first. |
| Sensitive permissions | Declare and explain microphone access. If a production microphone foreground service is shipped, complete its declarations for the exact use case. |
| App signing | Enrol in Play App Signing and upload a signed Android App Bundle (`.aab`). |

## Data safety – AdMob notes

### VoiceMate's own on-device processing
- Microphone samples processed only in memory and never sent off-device by VoiceMate: do not declare this as data collected solely because it is accessed locally. Re-check if later code uploads, records, or logs audio.
- On-device settings and event metadata that never leave the device: check current Play Data safety guidance for on-device-only processing.
- No account, contacts, SMS, call log or precise-location feature is planned.

### Google Mobile Ads SDK
Google's Android Mobile Ads SDK disclosure states that it automatically collects and shares IP address, user product interactions, diagnostic information, and device/account identifiers for advertising, analytics and fraud prevention. IP address may be used to estimate general/approximate location. Ad ID collection is optional/configuration-dependent. Google states SDK data is encrypted in transit using TLS.

Prepare to declare the data types/purposes that match the exact SDK integration and configuration, likely including:
- Approximate location (where IP is used to infer general location).
- App interactions.
- Diagnostics.
- Device or other identifiers.

Purposes to evaluate: advertising or marketing, analytics, fraud prevention/security/compliance, and ad measurement. Mark collection/sharing and whether data is optional or required according to the actual shipped SDK and configuration. Do not copy selections blindly; re-check Google's current SDK disclosure before each release.

Official reference: https://developers.google.com/admob/android/privacy/play-data-disclosure

## Technical release requirements
- New apps submitted from **31 August 2026** must target **Android 16 / API level 36 or higher**. Verify the Gradle configuration and built AAB.
- Application ID: `com.dev.voicemate`.
- Current starter version: `0.1.0+1`; increment versionCode for every Play release.
- Upload an Android App Bundle (`.aab`), not a debug APK.
- Test internal/closed tracks before production.
- Ensure screenshots depict the actual current app experience.
- Review merged manifest permissions, microphone foreground-service declaration (if background monitoring is implemented), privacy policy, Data safety and ad disclosures together.

## Reviewer access instructions

For a build in which the foreground clap test is available:

`No account or sign-in is required. Launch VoiceMate, complete the short onboarding flow, open the Home tab, choose Clap Detection Lab, tap Start clap test, and grant microphone permission. The test runs only while the screen is open. Tap Stop test to end microphone capture.`

If a feature is not present in the submitted build, remove it from the listing and reviewer instructions.

## Remaining information the developer must supply
- Real support email address.
- Confirmed final developer display name and business/contact details in Play Console.
- Final target audience and content-rating questionnaire answers.
- Final country availability and default language/localisations.
- AdMob app ID and ad unit IDs (do not commit live IDs/secrets; use test IDs during development).
- Public HTTPS privacy policy URL after hosting and a functioning in-app privacy link.
- Actual screenshots from the release build.
- Final AAB, signing, Data safety answers and permissions declarations.

## Official references
- Preview asset sizes and screenshot rules: https://support.google.com/googleplay/android-developer/answer/9866151
- Prepare app for review: https://support.google.com/googleplay/android-developer/answer/9859455
- Store listing fields and character limits: https://support.google.com/googleplay/android-developer/answer/9859152
- Target API requirements: https://support.google.com/googleplay/android-developer/answer/11926878
- Google Mobile Ads Data safety disclosure: https://developers.google.com/admob/android/privacy/play-data-disclosure
