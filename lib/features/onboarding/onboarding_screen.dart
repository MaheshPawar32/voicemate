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
      icon: Icons.hearing_rounded,
      title: 'Find your phone with sound',
      description:
          'Start the finder while VoiceMate is open, then use a clap or a steady whistle-like tone to trigger your selected alert. A persistent Android notification keeps Stop within reach.',
      label: 'SMART PHONE FINDER',
    ),
    _OnboardingItem(
      icon: Icons.record_voice_over_rounded,
      title: 'Use optional offline voice commands',
      description:
          'Install the English (US) speech model once. After setup, supported commands are recognised on this phone without a cloud speech service.',
      label: 'ON-DEVICE VOICE',
    ),
    _OnboardingItem(
      icon: Icons.shield_outlined,
      title: 'Your controls stay in your hands',
      description:
          'Microphone access starts only after a clear disclosure and your action. Audio is processed locally; settings and event history stay on this device. You can stop monitoring at any time.',
      label: 'PRIVACY & CONTROL',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final item = _items[_page];
    final compact = MediaQuery.sizeOf(context).height < 700;
    final illustrationSize = compact ? 148.0 : 190.0;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(24, 18, 24, compact ? 20 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.graphic_eq_rounded,
                    color: VoiceMateApp.cyan,
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'VoiceMate',
                    style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: widget.onComplete,
                    child: const Text('Skip'),
                  ),
                ],
              ),
              SizedBox(height: compact ? 22 : 42),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 280),
                child: Container(
                  key: ValueKey(item.label),
                  width: illustrationSize,
                  height: illustrationSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: VoiceMateApp.cyan.withValues(alpha: .07),
                    border: Border.all(
                      color: VoiceMateApp.cyan.withValues(alpha: .22),
                    ),
                  ),
                  child: Icon(
                    item.icon,
                    size: illustrationSize * .46,
                    color: VoiceMateApp.cyan,
                  ),
                ),
              ),
              SizedBox(height: compact ? 22 : 38),
              Text(
                item.label,
                style: const TextStyle(
                  color: VoiceMateApp.cyan,
                  letterSpacing: 2,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 13),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  item.title,
                  key: ValueKey(item.title),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: compact ? 25 : 29,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 13),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                child: Text(
                  item.description,
                  key: ValueKey(item.description),
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VoiceMateApp.muted,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ),
              SizedBox(height: compact ? 26 : 38),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(
                  _items.length,
                  (index) => AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    width: index == _page ? 24 : 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: index == _page
                          ? VoiceMateApp.cyan
                          : VoiceMateApp.muted.withValues(alpha: .35),
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 22),
              FilledButton(
                onPressed: () {
                  if (_page == _items.length - 1) {
                    widget.onComplete();
                  } else {
                    setState(() => _page++);
                  }
                },
                style: FilledButton.styleFrom(
                  backgroundColor: VoiceMateApp.cyan,
                  foregroundColor: const Color(0xFF06111D),
                  minimumSize: const Size.fromHeight(54),
                ),
                child: Text(
                  _page == _items.length - 1 ? 'Get started' : 'Continue',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
    required this.label,
  });

  final IconData icon;
  final String title;
  final String description;
  final String label;
}
