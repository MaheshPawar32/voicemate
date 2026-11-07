import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/monitoring_controller.dart';
import 'finder_settings_common.dart';

class PocketModeScreen extends StatefulWidget {
  const PocketModeScreen({super.key});

  @override
  State<PocketModeScreen> createState() => _PocketModeScreenState();
}

class _PocketModeScreenState extends State<PocketModeScreen> {
  final _c = MonitoringController.instance;
  bool? _hasSensor;

  @override
  void initState() {
    super.initState();
    _c.service.capabilities().then((caps) {
      if (mounted) setState(() => _hasSensor = caps['has_proximity'] as bool?);
    });
  }

  Future<void> _toggle(bool value) async {
    final prefs = _c.finderPreferences.read();
    await _c.finderPreferences.save(prefs.copyWith(pocketModeEnabled: value));
    if (mounted) {
      setState(() {});
      showSavedSnack(context, _c.active);
    }
  }

  @override
  Widget build(BuildContext context) {
    final enabled = _c.finderPreferences.read().pocketModeEnabled;
    final unsupported = _hasSensor == false;
    return Scaffold(
      appBar: AppBar(title: const Text('Pocket Mode')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
        children: [
          const DetectionHero(
            icon: Icons.inventory_2_outlined,
            text:
                'Prevent accidental alerts while your\nphone is in a pocket or bag.',
          ),
          const SizedBox(height: 18),
          ToggleRow(
            icon: Icons.sensors_rounded,
            title: 'Enable Pocket Mode',
            subtitle: unsupported
                ? 'Not available: no proximity sensor'
                : (_hasSensor == null
                    ? 'Checking sensor…'
                    : 'Uses the proximity sensor'),
            value: enabled && !unsupported,
            onChanged: unsupported ? null : _toggle,
          ),
          const SectionLabel('How it works'),
          const NeonCard(
            child: Text(
              'While monitoring, if the proximity sensor is covered, a clap or whistle is still '
              'logged in History but the alert stays silent — someone clapping near your pocket '
              'won’t make it ring.\n\n'
              'Stop controls always work, even when covered.',
              style: TextStyle(height: 1.5),
            ),
          ),
          const SizedBox(height: 12),
          const NoticeBanner(
            icon: Icons.info_outline_rounded,
            color: VokeyTokens.muted,
            message:
                'Proximity sensors differ between phones. Some only report “near” for a moment, '
                'and some phone cases cover the sensor permanently. If alerts never play, turn '
                'Pocket Mode off.',
          ),
        ],
      ),
    );
  }
}
