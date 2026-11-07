import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';

/// Shared hero used at the top of detection settings screens.
class DetectionHero extends StatelessWidget {
  const DetectionHero({super.key, required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Column(
        children: [
          const SizedBox(height: 8),
          Container(
            width: 112,
            height: 112,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2A6B), Color(0xFF3A1F7A)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: VokeyTokens.cyan.withValues(alpha: .5)),
              boxShadow: [
                BoxShadow(
                  color: VokeyTokens.violet.withValues(alpha: .35),
                  blurRadius: 30,
                ),
              ],
            ),
            child: Icon(icon, size: 54, color: VokeyTokens.cyan),
          ),
          const SizedBox(height: 14),
          Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VokeyTokens.muted, height: 1.45),
          ),
        ],
      );
}

void showSavedSnack(BuildContext context, bool monitoringActive) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        monitoringActive
            ? 'Saved. Stop and start the finder to apply.'
            : 'Saved. Used the next time you start the finder.',
      ),
    ),
  );
}
