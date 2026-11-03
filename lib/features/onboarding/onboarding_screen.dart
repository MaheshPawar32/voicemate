import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  int _page = 0;

  static const _items = [
    _OnboardingItem(
      icon: Icons.phone_android_rounded,
      title: 'Test clap detection',
      description: 'Try the microphone-based clap detector in a visible foreground test. More finder features are in development.',
      label: 'CLAP TEST',
    ),
    _OnboardingItem(
      icon: Icons.graphic_eq_rounded,
      title: 'Simple, offline-first',
      description: 'Your preferences stay on this device. Offline voice commands are planned for a future version.',
      label: 'ON-DEVICE DESIGN',
    ),
    _OnboardingItem(
      icon: Icons.shield_outlined,
      title: 'Microphone privacy',
      description: 'Microphone access is requested only when you start the clap test. Capture stops when you stop the test or leave the screen.',
      label: 'VISIBLE TEST ONLY',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[_page];
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
          child: Column(children: [
            Row(children: [
              const Icon(Icons.graphic_eq_rounded, color: VoiceMateApp.cyan),
              const SizedBox(width: 8),
              const Text('VoiceMate', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
              const Spacer(),
              TextButton(onPressed: widget.onComplete, child: const Text('Skip')),
            ]),
            const Spacer(),
            Container(
              width: 190, height: 190,
              decoration: BoxDecoration(shape: BoxShape.circle, color: VoiceMateApp.cyan.withOpacity(.07), border: Border.all(color: VoiceMateApp.cyan.withOpacity(.22))),
              child: Icon(item.icon, size: 88, color: VoiceMateApp.cyan),
            ),
            const SizedBox(height: 38),
            Text(item.label, style: const TextStyle(color: VoiceMateApp.cyan, letterSpacing: 2, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 13),
            Text(item.title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 29, fontWeight: FontWeight.w800)),
            const SizedBox(height: 13),
            Text(item.description, textAlign: TextAlign.center, style: const TextStyle(color: VoiceMateApp.muted, fontSize: 15, height: 1.55)),
            const Spacer(),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: List.generate(_items.length, (i) => AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: i == _page ? 24 : 7, height: 7,
              decoration: BoxDecoration(color: i == _page ? VoiceMateApp.cyan : VoiceMateApp.muted.withOpacity(.35), borderRadius: BorderRadius.circular(10)),
            ))),
            const SizedBox(height: 22),
            FilledButton(
              onPressed: () {
                if (_page == _items.length - 1) {
                  widget.onComplete();
                } else {
                  setState(() => _page++);
                }
              },
              style: FilledButton.styleFrom(backgroundColor: VoiceMateApp.cyan, foregroundColor: const Color(0xFF06111D), minimumSize: const Size.fromHeight(54)),
              child: Text(_page == _items.length - 1 ? 'Get started' : 'Continue'),
            ),
          ]),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({required this.icon, required this.title, required this.description, required this.label});
  final IconData icon;
  final String title;
  final String description;
  final String label;
}
