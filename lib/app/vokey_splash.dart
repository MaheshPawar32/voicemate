import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Brand tokens for the Vokey neon look (see assets/branding/reference).
class VokeyColors {
  static const background = Color(0xFF070A1E);
  static const cyan = Color(0xFF26D9E8);
  static const violet = Color(0xFF7777FF);
  static const magenta = Color(0xFFC85CFF);
  static const text = Color(0xFFF4F7FF);
  static const muted = Color(0xFF9BA9BE);

  static const brandGradient = LinearGradient(
    colors: [cyan, violet, magenta],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Animated launch screen shown while local storage opens.
///
/// One controller drives everything (entrance + glow pulse + waves) and is
/// disposed with the widget, so no animation outlives startup.
class VokeySplash extends StatefulWidget {
  const VokeySplash({super.key, this.status = 'Getting ready…'});

  final String status;

  @override
  State<VokeySplash> createState() => _VokeySplashState();
}

class _VokeySplashState extends State<VokeySplash>
    with TickerProviderStateMixin {
  late final AnimationController _entrance = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1100),
  )..forward();
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..repeat();

  @override
  void dispose() {
    _entrance.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final logoIn = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0, .65, curve: Curves.easeOutBack),
    );
    final textIn = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(.35, 1, curve: Curves.easeOutCubic),
    );
    return Scaffold(
      backgroundColor: VokeyColors.background,
      body: Stack(
        children: [
          Positioned.fill(
            child: AnimatedBuilder(
              animation: _loop,
              builder: (_, __) => CustomPaint(
                painter: _WavePainter(_loop.value, textIn.value),
              ),
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: Listenable.merge([_entrance, _loop]),
                  builder: (_, child) {
                    final pulse = .5 + .5 * math.sin(_loop.value * 2 * math.pi);
                    return Opacity(
                      opacity: logoIn.value.clamp(0, 1).toDouble(),
                      child: Transform.scale(
                        scale: .6 + .4 * logoIn.value,
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(38),
                            boxShadow: [
                              BoxShadow(
                                color: VokeyColors.cyan
                                    .withValues(alpha: .18 + .22 * pulse),
                                blurRadius: 30 + 26 * pulse,
                                spreadRadius: 2,
                              ),
                              BoxShadow(
                                color: VokeyColors.magenta
                                    .withValues(alpha: .10 + .16 * (1 - pulse)),
                                blurRadius: 46,
                                offset: const Offset(10, 14),
                              ),
                            ],
                          ),
                          child: child,
                        ),
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(38),
                    child: Image.asset(
                      'assets/branding/vokey_icon_1024.png',
                      width: 164,
                      height: 164,
                      filterQuality: FilterQuality.medium,
                      semanticLabel: 'Vokey logo',
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                FadeTransition(
                  opacity: textIn,
                  child: SlideTransition(
                    position: Tween(
                      begin: const Offset(0, .35),
                      end: Offset.zero,
                    ).animate(textIn),
                    child: Column(
                      children: [
                        ShaderMask(
                          shaderCallback: (r) => const LinearGradient(colors: [
                            VokeyColors.text,
                            VokeyColors.cyan,
                            VokeyColors.text,
                          ], stops: [
                            .0,
                            .55,
                            1
                          ]).createShader(r),
                          child: const Text(
                            'Vokey',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 46,
                              fontWeight: FontWeight.w900,
                              letterSpacing: .5,
                            ),
                          ),
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Find your phone.\nJust use your voice.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: VokeyColors.muted,
                            fontSize: 16,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 30),
                        _LoadingDots(animation: _loop),
                        const SizedBox(height: 12),
                        Text(
                          widget.status,
                          style: const TextStyle(
                            color: VokeyColors.muted,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingDots extends StatelessWidget {
  const _LoadingDots({required this.animation});
  final Animation<double> animation;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Loading',
        child: AnimatedBuilder(
          animation: animation,
          builder: (_, __) => Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (i) {
              final t = (animation.value * 2 - i * .12) * math.pi * 2;
              final h = 8 + 14 * (.5 + .5 * math.sin(t));
              return Container(
                width: 5,
                height: h,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                decoration: BoxDecoration(
                  gradient: VokeyColors.brandGradient,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),
      );
}

/// Layered neon sine waves anchored to the bottom of the screen.
class _WavePainter extends CustomPainter {
  _WavePainter(this.t, this.reveal);
  final double t;
  final double reveal;

  @override
  void paint(Canvas canvas, Size size) {
    if (reveal <= 0) return;
    final base = size.height * .86;
    const layers = [
      (
        amp: 26.0,
        len: 1.15,
        speed: 1.0,
        colors: [VokeyColors.cyan, VokeyColors.violet],
        a: .55
      ),
      (
        amp: 18.0,
        len: .85,
        speed: -1.0,
        colors: [VokeyColors.violet, VokeyColors.magenta],
        a: .45
      ),
      (
        amp: 12.0,
        len: 1.6,
        speed: 2.0,
        colors: [VokeyColors.cyan, VokeyColors.magenta],
        a: .35
      ),
    ];
    for (var i = 0; i < layers.length; i++) {
      final l = layers[i];
      final path = Path()..moveTo(0, size.height);
      for (double x = 0; x <= size.width; x += 4) {
        final phase = t * 2 * math.pi * l.speed + i;
        final y = base +
            i * 10 +
            math.sin(x / size.width * 2 * math.pi * l.len + phase) * l.amp;
        path.lineTo(x, y);
      }
      path
        ..lineTo(size.width, size.height)
        ..close();
      final rect =
          Rect.fromLTWH(0, base - 40, size.width, size.height - base + 40);
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              l.colors[0].withValues(alpha: l.a * reveal),
              l.colors[1].withValues(alpha: l.a * .6 * reveal),
              VokeyColors.background.withValues(alpha: 0),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ).createShader(rect),
      );
    }
  }

  @override
  bool shouldRepaint(_WavePainter old) => old.t != t || old.reveal != reveal;
}
