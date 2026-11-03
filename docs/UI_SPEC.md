# VoiceMate UI Design Specification

Use the generated VoiceMate UI concept image from the project conversation as the visual reference.

## Design tokens
| Token | Hex |
|---|---|
| Background | #0B1020 |
| Surface | #131B2E |
| Card | #19243A |
| Cyan accent | #26D9E8 |
| Violet accent | #7777FF |
| Main text | #F4F7FF |
| Secondary text | #9BA9BE |
| Success | #38D99A |
| Warning | #FFBE55 |
| Error | #FF657A |

## Global style
- Android-first, responsive layouts.
- Rounded cards (16–22 dp), subtle borders and restrained gradients.
- Cyan waveform/microphone visual language.
- Dark theme first; light theme later.
- Readable typography, scalable text, accessible labels and comfortable touch targets.
- Avoid excessive glassmorphism and battery-draining animation.

## Screen composition
### Splash
VoiceMate audio mark, name and tagline. No network wait or forced ad.

### Onboarding
Three concise slides: Find your phone; Control your phone; Privacy matters. Skip/Next/Get Started. Request microphone permission only when the user enables a feature.

### Home dashboard
App title and settings shortcut; greeting; clear Monitoring OFF/ON status; prominent microphone/waveform card with explicit Start/Stop; quick feature grid (Clap, Whistle, Voice, Alert Studio); bottom navigation Home/Discover/History/Settings. Never place an interstitial on launch.

### Smart Finder
Finder enable control, detection methods, sound/flash/vibration options, test alert and clear service state.

### Clap Detection
Enable switch, signal visualisation, sensitivity, single/double/triple pattern, cooldown, noise filtering and test state.

### Whistle Detection
Enable switch, supported frequency range, sensitivity, minimum duration, cooldown and limitations note.

### Voice Commands
Offline engine readiness, installed model/language, tested command list and local-processing explanation.

### Screen Lock
Optional enable action, administrator explanation, phrase setup and prominent “screen lock only; no voice unlock” disclosure.

### Alert Studio
Sound selection, volume, duration, repeat, flashlight and vibration pattern controls with test/stop.

### Settings
General, detection, monitoring, privacy and about sections; theme/language, sound, vibration, history clearing and permissions.

## Interaction requirements
No fake toggles. Persist settings. Disabled features explain why. Permission prompts follow in-app education. Active monitoring remains obvious and the persistent notification provides Stop. Ads do not cover controls or interrupt active use.
