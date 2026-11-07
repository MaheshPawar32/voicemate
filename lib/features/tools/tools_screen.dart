import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../alert_studio/alert_studio_screen.dart';
import '../analytics/analytics_screen.dart';
import '../clap_detection/clap_test_screen.dart';
import '../finder/battery_aware_screen.dart';
import '../finder/clap_detection_screen.dart';
import '../finder/pocket_mode_screen.dart';
import '../finder/smart_finder_screen.dart';
import '../finder/whistle_detection_screen.dart';
import '../permissions/permission_centre_screen.dart';
import '../sound_library/sound_library_screen.dart';
import '../voice_commands/voice_commands_screen.dart';
import '../voice_lock/voice_screen_lock_screen.dart';

class _Tool {
  const _Tool(this.icon, this.title, this.subtitle, this.color, this.builder);
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final WidgetBuilder builder;
}

class ToolsScreen extends StatelessWidget {
  const ToolsScreen({super.key});

  static final _tools = <_Tool>[
    _Tool(Icons.radar_rounded, 'Smart Finder', 'Methods & cooldown',
        VokeyTokens.cyan, (_) => const SmartFinderScreen()),
    _Tool(Icons.back_hand_rounded, 'Clap', 'Pattern & sensitivity',
        VokeyTokens.cyan, (_) => const ClapDetectionScreen()),
    _Tool(Icons.sports_rounded, 'Whistle', 'Range & duration', VokeyTokens.cyan,
        (_) => const WhistleDetectionScreen()),
    _Tool(Icons.mic_rounded, 'Voice', 'Offline commands', VokeyTokens.violet,
        (_) => const VoiceCommandsScreen()),
    _Tool(Icons.science_rounded, 'Finder Test', 'Try it on this phone',
        VokeyTokens.success, (_) => const ClapTestScreen()),
    _Tool(
        Icons.notifications_active_rounded,
        'Alert Studio',
        'Sound, vibration, flash',
        VokeyTokens.magenta,
        (_) => const AlertStudioScreen()),
    _Tool(Icons.library_music_rounded, 'Sound Library', 'Alert tones',
        VokeyTokens.magenta, (_) => const SoundLibraryScreen()),
    _Tool(Icons.inventory_2_outlined, 'Pocket Mode', 'Quiet in pockets',
        VokeyTokens.violet, (_) => const PocketModeScreen()),
    _Tool(Icons.battery_charging_full_rounded, 'Battery', 'Warning & auto-stop',
        VokeyTokens.success, (_) => const BatteryAwareScreen()),
    _Tool(Icons.verified_user_rounded, 'Permission Health', 'Access & hardware',
        VokeyTokens.warning, (_) => const PermissionCentreScreen()),
    _Tool(Icons.insights_rounded, 'Analytics', 'Detections & time',
        VokeyTokens.cyan, (_) => const AnalyticsScreen()),
    _Tool(Icons.lock_outline_rounded, 'Screen Lock', 'Lock-only shortcut',
        VokeyTokens.muted, (_) => const VoiceScreenLockScreen()),
  ];

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Tools')),
        body: GridView.builder(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
            maxCrossAxisExtent: 200,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: _tools.length,
          itemBuilder: (context, i) {
            final t = _tools[i];
            return NeonCard(
              onTap: () => Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: t.builder)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  IconBadge(icon: t.icon, color: t.color),
                  const Spacer(),
                  Text(t.title,
                      style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 3),
                  Text(
                    t.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        const TextStyle(color: VokeyTokens.muted, fontSize: 12),
                  ),
                ],
              ),
            );
          },
        ),
      );
}
