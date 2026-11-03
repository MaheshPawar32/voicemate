import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
        children: [
          Row(children: [
            const Expanded(child: Text('VoiceMate', style: TextStyle(fontSize: 25, fontWeight: FontWeight.w800))),
            IconButton(onPressed: () {}, icon: const Icon(Icons.notifications_none_rounded)),
          ]),
          const SizedBox(height: 20),
          Row(children: [
            const Expanded(child: Text('Your phone,\nnever lost.', style: TextStyle(fontSize: 27, height: 1.15, fontWeight: FontWeight.w800))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
              decoration: BoxDecoration(color: const Color(0xFF302A20), borderRadius: BorderRadius.circular(30)),
              child: const Row(children: [Icon(Icons.circle, size: 8, color: Color(0xFFFFBE55)), SizedBox(width: 7), Text('OFF', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]),
            ),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(23),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [Color(0xFF18365A), Color(0xFF111D32)], begin: Alignment.topLeft, end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: VoiceMateApp.cyan.withOpacity(.25)),
            ),
            child: Column(children: [
              Container(
                width: 112, height: 112,
                decoration: BoxDecoration(shape: BoxShape.circle, color: VoiceMateApp.cyan.withOpacity(.09), border: Border.all(color: VoiceMateApp.cyan.withOpacity(.35), width: 1.5)),
                child: const Icon(Icons.graphic_eq_rounded, size: 58, color: VoiceMateApp.cyan),
              ),
              const SizedBox(height: 17),
              const Text('Finder is paused', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 7),
              const Text('Choose how VoiceMate should help you find your phone. Monitoring is not active.', textAlign: TextAlign.center, style: TextStyle(color: VoiceMateApp.muted, height: 1.45)),
              const SizedBox(height: 18),
              FilledButton.icon(
                onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('The microphone service is not implemented yet.'))),
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Set up finder'),
                style: FilledButton.styleFrom(backgroundColor: VoiceMateApp.cyan, foregroundColor: const Color(0xFF06111D), minimumSize: const Size.fromHeight(50)),
              ),
            ]),
          ),
          const SizedBox(height: 25),
          const Text('Quick tools', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 13),
          const Wrap(spacing: 12, runSpacing: 12, children: [
            _ToolCard(icon: Icons.back_hand_rounded, title: 'Clap to Find', detail: 'Sound trigger'),
            _ToolCard(icon: Icons.graphic_eq_rounded, title: 'Whistle to Find', detail: 'Tone trigger'),
            _ToolCard(icon: Icons.mic_none_rounded, title: 'Voice Commands', detail: 'Offline control'),
            _ToolCard(icon: Icons.notifications_active_outlined, title: 'Alert Studio', detail: 'Sound & flash'),
          ]),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: VoiceMateApp.surface, borderRadius: BorderRadius.circular(18)),
            child: const Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Icon(Icons.shield_outlined, color: VoiceMateApp.cyan),
              SizedBox(width: 12),
              Expanded(child: Text('Privacy comes first\nAudio will be processed on this device. VoiceMate does not require an account.', style: TextStyle(height: 1.45))),
            ]),
          ),
        ],
      ),
    );
  }
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({required this.icon, required this.title, required this.detail});
  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: (MediaQuery.sizeOf(context).width - 52) / 2,
    child: Card(child: Padding(
      padding: const EdgeInsets.all(15),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: VoiceMateApp.cyan, size: 28),
        const SizedBox(height: 13),
        Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(detail, style: const TextStyle(color: VoiceMateApp.muted, fontSize: 12)),
      ]),
    )),
  );
}
