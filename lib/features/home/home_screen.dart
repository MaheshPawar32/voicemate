import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';
import '../clap_detection/clap_test_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _openClapTest(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ClapTestScreen()),
    );
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Text('VoiceMate', style: TextStyle(
          fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Text('Your phone,\nnever lost.',
            style: TextStyle(
              fontSize: 27, height: 1.15, fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF302A20),
              borderRadius: BorderRadius.circular(30)),
            child: const Row(children: [
              Icon(Icons.circle, size: 8, color: Color(0xFFFFBE55)),
              SizedBox(width: 7),
              Text('MONITORING OFF', style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF18365A), Color(0xFF111D32)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: VoiceMateApp.cyan.withValues(alpha: .25)),
          ),
          child: Column(children: [
            Container(
              width: 112, height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VoiceMateApp.cyan.withValues(alpha: .09),
                border: Border.all(
                  color: VoiceMateApp.cyan.withValues(alpha: .35),
                  width: 1.5)),
              child: const Icon(Icons.graphic_eq_rounded,
                size: 58, color: VoiceMateApp.cyan)),
            const SizedBox(height: 17),
            const Text('Monitoring is off', style: TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            const Text(
              'The background phone finder is not enabled. You can run the foreground microphone diagnostic below.',
              textAlign: TextAlign.center,
              style: TextStyle(color: VoiceMateApp.muted, height: 1.45)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: () => _openClapTest(context),
              icon: const Icon(Icons.hearing_rounded),
              label: const Text('Run clap detection test'),
              style: FilledButton.styleFrom(
                backgroundColor: VoiceMateApp.cyan,
                foregroundColor: const Color(0xFF06111D),
                minimumSize: const Size.fromHeight(50)),
            ),
          ]),
        ),
        const SizedBox(height: 25),
        const Text('Available now', style: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 13),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => _openClapTest(context),
            child: const Padding(
              padding: EdgeInsets.all(16),
              child: Row(children: [
                Icon(Icons.back_hand_rounded,
                  color: VoiceMateApp.cyan, size: 30),
                SizedBox(width: 14),
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clap Detection Diagnostic',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Foreground microphone signal test',
                      style: TextStyle(
                        color: VoiceMateApp.muted, fontSize: 12)),
                  ],
                )),
                Icon(Icons.chevron_right_rounded),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoiceMateApp.surface,
            borderRadius: BorderRadius.circular(18)),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: VoiceMateApp.cyan),
              SizedBox(width: 12),
              Expanded(child: Text(
                'Privacy first\nThe microphone is used only during the visible test. Audio is analysed in memory and is not recorded or uploaded by VoiceMate.',
                style: TextStyle(height: 1.45))),
            ],
          ),
        ),
      ],
    ),
  );
}
