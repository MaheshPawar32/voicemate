# Clap Detection Feasibility Spike

## Goal
Determine whether a practical clap detector can distinguish intentional claps from everyday phone audio on target Android devices before building the full monitoring feature.

## Safety and privacy constraints
- Start capture only from an explicit tap in a visible test screen.
- Request microphone permission only after showing a clear explanation.
- Use a foreground service only for a later, justified background test; this initial spike is foreground-only.
- Process samples in memory. Do not save audio, transcripts, or microphone buffers.
- Log only numeric metrics and test labels. Do not include personal audio in crash logs.
- Provide an obvious Stop action and release AudioRecord on every exit/error path.

## Initial signal pipeline
1. Check RECORD_AUDIO permission and supported input configuration.
2. Create one AudioRecord instance and verify initialization.
3. Read short PCM frames (start with 10–20 ms frames; adapt to the actual device buffer).
4. Calculate frame RMS and peak amplitude.
5. Maintain a slowly adapting ambient noise estimate.
6. Detect a short transient when energy rises sufficiently above the noise estimate.
7. Evaluate transient duration and optional spectral/zero-crossing features.
8. Apply a refractory interval so one clap is not counted multiple times.
9. Group events into single/double/triple patterns using a configurable grouping window.
10. Emit only detection metadata to Flutter.

## Parameters to tune
Treat all values as experimental, not universal:
- Candidate sample rate: 16 kHz if supported; otherwise query supported rates.
- Frame duration: 10–20 ms.
- Candidate transient duration: roughly 40–200 ms.
- Refractory interval: begin around 250–450 ms.
- Pattern grouping window: begin around 500–900 ms.
- User-facing sensitivity: map to measured thresholds rather than raw microphone gain.

## Test matrix
For each device and environment, run at least:
- 20 intentional claps at near, medium and far distances.
- Speech and conversation.
- Music and television.
- Keyboard taps, door knocks and object drops.
- Fan/air-conditioner and street noise.
- Quiet room and reverberant room.
- Phone on a table, in a pocket/bag only if the microphone remains unobstructed.

Record:
- True detections / intentional claps.
- False detections per 10 minutes.
- Missed claps by distance.
- Detection latency.
- CPU/battery observations.
- Device model, Android version, input source and selected sample rate.

## Go/no-go criteria
Do not advertise reliable clap finding until tests demonstrate acceptable detection and false-positive rates across multiple physical devices. If noise rejection is poor, offer user calibration and clearly communicate limitations. Persistent background behavior must be evaluated separately under Android foreground-service rules and OEM battery management.

## Implementation boundary
Keep detector math in a pure Kotlin class that can be unit-tested with generated PCM fixtures. Keep AudioRecord lifecycle in a separate manager. Do not place signal processing in Activity or Flutter widgets.
