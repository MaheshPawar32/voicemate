import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/vokey_splash.dart';
import '../../core/widgets/gradient_button.dart';
import '../../services/telemetry_service.dart';

/// Three-slide introduction (reference: assets/branding/reference).
/// No permission is requested here; permissions follow in-context education.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, required this.onComplete});

  final VoidCallback onComplete;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  final _pages = PageController();
  late final AnimationController _glow = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2400),
  )..repeat();
  int _page = 0;

  static const _items = [
    _OnboardingItem(
      icon: Icons.phonelink_ring_rounded,
      title: 'Find Your Phone\nwith Sound',
      description:
          'Clap, whistle or use a supported voice command to make your phone ring, vibrate or flash — while monitoring is on and its notification is visible.',
    ),
    _OnboardingItem(
      icon: Icons.mic_rounded,
      title: 'Voice Commands\nthat Work Offline',
      description:
          'After a one-time download of the English speech model, phrases like “find my phone” are recognised on your device — no cloud speech service.',
    ),
    _OnboardingItem(
      icon: Icons.lock_rounded,
      title: 'Private & Secure',
      description:
          'Audio is processed on your device only. Vokey never saves recordings or uploads microphone audio. Stop monitoring any time.',
    ),
  ];

  bool get _isLast => _page == _items.length - 1;

  @override
  void dispose() {
    _pages.dispose();
    _glow.dispose();
    super.dispose();
  }

  void _next() {
    if (_isLast) {
      TelemetryService.instance.log('onboarding_completed');
      widget.onComplete();
    } else {
      _pages.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: VokeyColors.background,
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pages,
                  itemCount: _items.length,
                  onPageChanged: (i) => setState(() => _page = i),
                  itemBuilder: (_, i) => _OnboardingPage(
                    item: _items[i],
                    glow: _glow,
                  ),
                ),
              ),
              _Dots(count: _items.length, index: _page),
              const SizedBox(height: 22),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 240),
                  child: _isLast
                      ? GradientButton(
                          key: const ValueKey('start'),
                          label: 'Get Started',
                          onPressed: _next,
                        )
                      : Row(
                          key: const ValueKey('nav'),
                          children: [
                            TextButton(
                              onPressed: () {
                                TelemetryService.instance.log(
                                  'onboarding_skipped',
                                  {'page': _page + 1},
                                );
                                widget.onComplete();
                              },
                              child: const Text(
                                'Skip',
                                style: TextStyle(color: VokeyColors.muted),
                              ),
                            ),
                            const Spacer(),
                            SizedBox(
                              width: 140,
                              child: GradientButton(
                                label: 'Next',
                                onPressed: _next,
                              ),
                            ),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      );
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.item, required this.glow});

  final _OnboardingItem item;
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
        builder: (context, c) => SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _HeroArt(icon: item.icon, glow: glow),
                const SizedBox(height: 40),
                Text(
                  item.title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VokeyColors.text,
                    fontSize: 28,
                    height: 1.2,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  item.description,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: VokeyColors.muted,
                    fontSize: 15,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
}

/// Neon disc with expanding sound rings behind the slide icon.
class _HeroArt extends StatelessWidget {
  const _HeroArt({required this.icon, required this.glow});

  final IconData icon;
  final Animation<double> glow;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 230,
        height: 230,
        child: AnimatedBuilder(
          animation: glow,
          builder: (_, __) => CustomPaint(
            painter: _RingsPainter(glow.value),
            child: Center(
              child: Container(
                width: 132,
                height: 132,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    colors: [Color(0xFF1B2A6B), Color(0xFF3A1F7A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: VokeyColors.cyan.withValues(alpha: .55),
                    width: 1.6,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VokeyColors.violet.withValues(
                        alpha: .30 + .20 * math.sin(glow.value * 2 * math.pi),
                      ),
                      blurRadius: 40,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: ShaderMask(
                  shaderCallback: (r) =>
                      VokeyColors.brandGradient.createShader(r),
                  child: Icon(icon, size: 66, color: Colors.white),
                ),
              ),
            ),
          ),
        ),
      );
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.t);
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < 3; i++) {
      final p = (t + i / 3) % 1;
      final radius = 66 + p * (size.width / 2 - 66);
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Color.lerp(VokeyColors.cyan, VokeyColors.magenta, p)!
              .withValues(alpha: (1 - p) * .55),
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) => old.t != t;
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(
          count,
          (i) => AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: i == index ? 24 : 7,
            height: 7,
            decoration: BoxDecoration(
              gradient: i == index ? VokeyColors.brandGradient : null,
              color:
                  i == index ? null : VokeyColors.muted.withValues(alpha: .35),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
        ),
      );
}

class _OnboardingItem {
  const _OnboardingItem({
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;
}
