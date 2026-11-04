import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';

class PrivacyCentreScreen extends StatelessWidget {
  const PrivacyCentreScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Policy')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: const [
        Text('VoiceMate – Voice Control & Phone Finder',
          style: TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
        SizedBox(height: 6),
        Text('Effective date: 4 November 2026',
          style: TextStyle(color: VoiceMateApp.muted)),
        SizedBox(height: 18),
        _PolicySection(
          title: 'Microphone use',
          body: 'VoiceMate starts microphone capture only after you accept the in-app disclosure, tap Start and grant Android microphone permission. Finder monitoring can continue while the app is in the background as an Android microphone foreground service. An ongoing notification shows that monitoring is active and provides a Stop action. Audio is processed in temporary memory; VoiceMate does not save raw recordings or upload microphone audio.',
        ),
        _PolicySection(
          title: 'Offline voice commands',
          body: 'Voice commands are optional. When enabled, VoiceMate downloads the English (US) Vosk speech model once over HTTPS and stores it in app-private storage. The initial model download requires internet; recognition and supported command matching work locally after installation. VoiceMate does not save transcripts or send microphone audio to a cloud speech service.',
        ),
        _PolicySection(
          title: 'Local history and settings',
          body: 'Preferences and detection history are stored on this device. History contains event type, timestamp and limited numeric metadata only; it does not contain audio or transcripts. The history is limited to the latest 250 events and can be cleared in Settings. Clearing app storage or uninstalling the app removes the locally stored data and downloaded model.',
        ),
        _PolicySection(
          title: 'Optional screen lock',
          body: 'The optional Voice Screen Lock asks you to activate Android Device Admin. It uses the force-lock permission only. VoiceMate can lock the screen after your explicit action, but it cannot unlock the phone, read your PIN, or bypass your pattern, password or biometrics.',
        ),
        _PolicySection(
          title: 'Battery and device readings',
          body: 'The Battery Centre reads battery level, charging state, reported health, temperature, voltage and Android power-saver status from system APIs. These readings are displayed locally.',
        ),
        _PolicySection(
          title: 'Network and advertising',
          body: 'Internet access is used for the optional one-time speech-model download. The current development build does not include an advertising SDK. Any advertising provider added to a future release will be described in an updated privacy policy and Google Play Data safety disclosure before publication.',
        ),
        _PolicySection(
          title: 'Permissions and your choices',
          body: 'Microphone and notification permissions are requested when the related feature needs them. Device Admin is optional and must be activated in Android by you. You can stop monitoring from the app or its notification, revoke permissions in Android settings, clear local history, deactivate Device Admin, or uninstall the app.',
        ),
        _PolicySection(
          title: 'Contact',
          body: 'For privacy questions or requests, use the developer contact details shown on the VoiceMate Google Play Store listing. Developer contact details must be published and monitored before release.',
        ),
        SizedBox(height: 8),
        Text(
          'Detection accuracy and background availability depend on the device, Android version, microphone, environment and manufacturer power-management settings.',
          style: TextStyle(color: VoiceMateApp.muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class _PolicySection extends StatelessWidget {
  const _PolicySection({required this.title, required this.body});
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 18),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(
          fontSize: 16, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text(body, style: const TextStyle(
          color: VoiceMateApp.muted, height: 1.55)),
      ],
    ),
  );
}
