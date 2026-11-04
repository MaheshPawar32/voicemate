import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const _sections = <_PolicySection>[
    _PolicySection(
      'Microphone and audio',
      'VoiceMate uses the microphone only after you accept the in-app disclosure, choose Start and grant Android microphone permission. The finder runs as a visible Android microphone foreground service with an ongoing notification and Stop action. Audio is analysed in temporary memory on your phone. VoiceMate does not save raw audio recordings or upload microphone audio.',
    ),
    _PolicySection(
      'Offline voice recognition',
      'Offline voice commands are optional. When you choose to install them, VoiceMate downloads the English (US) Vosk model over HTTPS and stores it in app-private storage. The installer verifies the archive checksum before extraction. Recognition and command matching happen on your phone. VoiceMate does not save transcripts or send speech to a cloud service. The initial model download requires internet access.',
    ),
    _PolicySection(
      'Local settings and history',
      'Your preferences and detection history are stored locally using app-private storage. History records event type, timestamp and limited numeric metadata such as a clap count or whistle frequency. It is capped at 250 events. You can clear it from Settings. VoiceMate does not have an account or cloud database.',
    ),
    _PolicySection(
      'Flashlight',
      'Flashlight alerts are optional and require Camera permission on supported Android versions. VoiceMate uses Android torch control only; it does not open a camera preview, take photos or record video. Some devices do not have a rear flash, and Android may temporarily make the torch unavailable while another app uses the camera.',
    ),
    _PolicySection(
      'Battery and device information',
      'The Battery Centre reads battery level, charging state, reported health, temperature, voltage and Android power-saver information. These readings are displayed locally and are not uploaded by VoiceMate.',
    ),
    _PolicySection(
      'Optional screen lock',
      'The screen-lock shortcut requires you to activate Android Device Admin yourself. It uses the force-lock policy only. VoiceMate cannot unlock your device, read your PIN, pattern or password, or bypass biometrics. You can deactivate the permission in Android settings.',
    ),
    _PolicySection(
      'Advertising and third parties',
      'VoiceMate integrates Google Mobile Ads and the Google User Messaging Platform (UMP). UMP refreshes consent information on app launch and presents any consent form required for the user. Banner requests are made only when UMP reports that ads may be requested. In the current layout, a banner can appear on Home while finder monitoring is off; it is hidden during monitoring and other feature screens. Debug builds use Google test ads. Release banners remain disabled until a real AdMob banner unit ID is configured. When an ad request is made, Google Mobile Ads may process network, device, advertising, app-interaction and diagnostic information under Google’s service terms. The optional voice-model download also sends a normal HTTPS request to the model host, which can see standard network metadata such as your IP address.',
    ),
    _PolicySection(
      'Your choices',
      'You can stop finder monitoring in the app or from the ongoing notification, revoke microphone, camera and notification permissions in Android settings, deactivate Device Admin, and clear local history or all app storage. Clearing app storage also removes the downloaded voice model.',
    ),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Privacy Policy')),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF19335A), Color(0xFF111D32)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('VOICE MATE',
                style: TextStyle(
                  color: VoiceMateApp.cyan,
                  letterSpacing: 1.6,
                  fontWeight: FontWeight.w800,
                  fontSize: 11,
                )),
              SizedBox(height: 8),
              Text('Privacy comes first',
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.w800)),
              SizedBox(height: 8),
              Text(
                'VoiceMate is designed to process finder audio on your device. No account is required.',
                style: TextStyle(color: VoiceMateApp.muted, height: 1.5),
              ),
              SizedBox(height: 12),
              Text('Last reviewed: 5 November 2026',
                style: TextStyle(color: VoiceMateApp.muted, fontSize: 11)),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            color: VoiceMateApp.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: VoiceMateApp.cyan.withValues(alpha: .18)),
          ),
          child: const Text(
            'Important: When monitoring is active, Android shows a persistent notification. Use its Stop action or the in-app control to end microphone monitoring.',
            style: TextStyle(height: 1.5),
          ),
        ),
        const SizedBox(height: 16),
        ..._sections.map((section) => Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(section.title, style: const TextStyle(
                  fontSize: 16, fontWeight: FontWeight.w800)),
                const SizedBox(height: 8),
                Text(section.body, style: const TextStyle(
                  color: VoiceMateApp.muted, height: 1.55)),
              ],
            ),
          ),
        )),
        const SizedBox(height: 12),
        const Text(
          'This in-app summary describes the current development implementation. The externally hosted policy and Play Store Data safety form must always match the exact version that is released.',
          style: TextStyle(color: VoiceMateApp.muted, fontSize: 12, height: 1.5),
        ),
      ],
    ),
  );
}

class _PolicySection {
  const _PolicySection(this.title, this.body);
  final String title;
  final String body;
}
