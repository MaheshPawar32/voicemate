import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/finder_preferences_repository.dart';
import '../../services/monitoring_controller.dart';
import 'finder_settings_common.dart';

class WhistleDetectionScreen extends StatefulWidget {
  const WhistleDetectionScreen({super.key});

  @override
  State<WhistleDetectionScreen> createState() => _WhistleDetectionScreenState();
}

class _WhistleDetectionScreenState extends State<WhistleDetectionScreen> {
  final _c = MonitoringController.instance;
  late FinderPreferences _draft = _c.finderPreferences.read();

  static String _khz(int hz) => '${(hz / 1000).toStringAsFixed(1)} kHz';

  Future<void> _save() async {
    await _c.finderPreferences.save(_draft);
    if (mounted) showSavedSnack(context, _c.active);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Whistle Detection')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
          children: [
            const DetectionHero(
              icon: Icons.sports_rounded,
              text:
                  'Detects a clear, steady whistle\nwithin a set frequency range.',
            ),
            const SizedBox(height: 18),
            NeonCard(
              child: LabeledSlider(
                label: 'Sensitivity',
                value: _draft.whistleSensitivityPct.toDouble(),
                min: 0,
                max: 100,
                divisions: 20,
                display: '${_draft.whistleSensitivityPct}%',
                onChanged: (v) => setState(
                  () => _draft =
                      _draft.copyWith(whistleSensitivityPct: v.round()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            NeonCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text('Frequency range',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const Spacer(),
                      Text(
                        '${_khz(_draft.whistleMinHz)} – ${_khz(_draft.whistleMaxHz)}',
                        style: const TextStyle(color: VokeyTokens.muted),
                      ),
                    ],
                  ),
                  RangeSlider(
                    values: RangeValues(
                      _draft.whistleMinHz.toDouble(),
                      _draft.whistleMaxHz.toDouble(),
                    ),
                    min: 800,
                    max: 6000,
                    divisions: 52,
                    labels: RangeLabels(
                      _khz(_draft.whistleMinHz),
                      _khz(_draft.whistleMaxHz),
                    ),
                    onChanged: (r) {
                      final lo = r.start.round();
                      var hi = r.end.round();
                      if (hi - lo < 200) hi = lo + 200;
                      setState(() => _draft = _draft.copyWith(
                            whistleMinHz: lo,
                            whistleMaxHz: hi,
                          ));
                    },
                  ),
                  const Text(
                    'Most people whistle between 1.5 and 4 kHz.',
                    style: TextStyle(color: VokeyTokens.muted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            NeonCard(
              child: LabeledSlider(
                label: 'Minimum duration',
                value: _draft.whistleMinDurationMs.toDouble(),
                min: 60,
                max: 1000,
                divisions: 47,
                display:
                    '${(_draft.whistleMinDurationMs / 1000).toStringAsFixed(2)} s',
                onChanged: (v) => setState(
                  () =>
                      _draft = _draft.copyWith(whistleMinDurationMs: v.round()),
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'A longer minimum ignores short beeps and bird calls but needs a longer whistle. '
              'Detection is tuned on test signals; check it on your phone in Finder Test.',
              style: TextStyle(
                  color: VokeyTokens.muted, fontSize: 12.5, height: 1.4),
            ),
            const SizedBox(height: 26),
            GradientButton(label: 'Save', onPressed: _save),
          ],
        ),
      );
}
