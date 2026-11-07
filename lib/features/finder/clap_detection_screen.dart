import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/finder_preferences_repository.dart';
import '../../services/monitoring_controller.dart';
import 'finder_settings_common.dart';
import '../../services/telemetry_service.dart';

class ClapDetectionScreen extends StatefulWidget {
  const ClapDetectionScreen({super.key});

  @override
  State<ClapDetectionScreen> createState() => _ClapDetectionScreenState();
}

class _ClapDetectionScreenState extends State<ClapDetectionScreen> {
  final _c = MonitoringController.instance;
  late FinderPreferences _draft = _c.finderPreferences.read();

  Future<void> _save() async {
    await _c.finderPreferences.save(_draft);
    TelemetryService.instance.log('detection_settings_saved', {
      'detector': 'clap',
      'clap_pattern': _draft.clapPattern,
      'sensitivity': _draft.clapSensitivityPct,
    });
    if (mounted) showSavedSnack(context, _c.active);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Clap Detection')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const DetectionHero(
              icon: Icons.back_hand_rounded,
              text:
                  'Detects single, double or triple claps\nto find your phone.',
            ),
            const SectionLabel('Clap pattern'),
            PillSegments<int>(
              options: FinderPreferences.clapPatterns,
              value: _draft.clapPattern,
              onChanged: (v) =>
                  setState(() => _draft = _draft.copyWith(clapPattern: v)),
            ),
            const SizedBox(height: 8),
            const Text(
              'Double and triple patterns are harder to trigger by accident (doors, music beats). '
              'Claps must be less than a second apart.',
              style: TextStyle(
                  color: VokeyTokens.muted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 18),
            NeonCard(
              child: LabeledSlider(
                label: 'Sensitivity',
                value: _draft.clapSensitivityPct.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                display: '${_draft.clapSensitivityPct}%',
                onChanged: (v) => setState(
                  () => _draft = _draft.copyWith(clapSensitivityPct: v.round()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Higher sensitivity hears quieter claps from further away but may react to other sharp sounds. '
              'Tune it in Finder Test.',
              style: TextStyle(
                  color: VokeyTokens.muted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 26),
            GradientButton(label: 'Save', onPressed: _save),
          ],
        ),
      );
}
