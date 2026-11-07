import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/history_repository.dart';
import '../../services/monitoring_controller.dart';
import '../../services/telemetry_service.dart';

/// "Phone Found!" (reference board). Shown in-app when a detection arrives
/// while Vokey is in the foreground; in the background the native
/// notification offers the same Stop / Snooze actions.
class PhoneFoundScreen extends StatefulWidget {
  const PhoneFoundScreen({super.key, required this.detection});

  final DetectionInfo detection;

  @override
  State<PhoneFoundScreen> createState() => _PhoneFoundScreenState();
}

class _PhoneFoundScreenState extends State<PhoneFoundScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  );

  MonitoringController get _c => MonitoringController.instance;

  @override
  void initState() {
    super.initState();
    // Animate only while the alert is actually sounding.
    if (widget.detection.alertPlayed) _pulse.repeat(reverse: true);
    HapticFeedback.heavyImpact();
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  Future<void> _feedback(String value) async {
    if (value == HistoryRepository.feedbackFalseAlarm) {
      TelemetryService.instance
          .log('false_alarm_reported', {'method': widget.detection.eventType});
    }
    final id = widget.detection.historyId;
    if (id != null) await _c.history.setFeedback(id, value);
  }

  Future<void> _close(Future<void> Function() action,
      {String? feedback}) async {
    if (feedback != null) await _feedback(feedback);
    await action();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.detection;
    final icon = switch (d.eventType) {
      'clap' => Icons.back_hand_rounded,
      'whistle' => Icons.sports_rounded,
      _ => Icons.mic_rounded,
    };
    final suppressed = switch (d.suppressedReason) {
      'quiet_hours' => 'Alert muted: quiet hours are on.',
      'pocket_mode' => 'Alert muted: your phone seemed to be in a pocket.',
      _ => null,
    };
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.close_rounded),
                ),
              ),
              const Spacer(),
              ScaleTransition(
                scale: Tween(begin: .94, end: 1.06).animate(
                  CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
                ),
                child: Container(
                  width: 168,
                  height: 168,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: VokeyTokens.violet, width: 4),
                    gradient: RadialGradient(colors: [
                      VokeyTokens.magenta.withValues(alpha: .35),
                      VokeyTokens.background,
                    ]),
                    boxShadow: [
                      BoxShadow(
                        color: VokeyTokens.magenta.withValues(alpha: .45),
                        blurRadius: 48,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.check_rounded,
                      size: 92, color: Colors.white),
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'Phone Found!',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: VokeyTokens.cyan),
                  const SizedBox(width: 8),
                  Text(
                    d.label,
                    style: const TextStyle(
                        fontSize: 17, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              if (suppressed != null) ...[
                const SizedBox(height: 14),
                NoticeBanner(message: suppressed, color: VokeyTokens.warning),
              ],
              const Spacer(),
              if (d.alertPlayed) ...[
                DangerButton(
                  label: 'Stop Alert',
                  icon: Icons.notifications_off_rounded,
                  onPressed: () => _close(_c.stopAlert,
                      feedback: HistoryRepository.feedbackFound),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _close(_c.snooze),
                  icon: const Icon(Icons.snooze_rounded),
                  label: const Text('Snooze (30s)'),
                ),
                const SizedBox(height: 4),
              ],
              TextButton(
                onPressed: () => _close(_c.stopAlert,
                    feedback: HistoryRepository.feedbackFalseAlarm),
                child: const Text("That wasn't me (false alarm)"),
              ),
              TextButton(
                onPressed: () => _close(_c.stop),
                style: TextButton.styleFrom(foregroundColor: VokeyTokens.muted),
                child: const Text('Stop listening'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
