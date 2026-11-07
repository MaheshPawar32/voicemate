import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme/vokey_theme.dart';
import '../../core/widgets/gradient_button.dart';
import '../../core/widgets/vokey_widgets.dart';
import '../../services/finder_monitoring_service.dart';
import '../../services/monitoring_controller.dart';
import '../../services/monitoring_settings_repository.dart';
import '../ads/home_banner_ad.dart';
import '../alert_studio/alert_studio_screen.dart';
import '../clap_detection/clap_test_screen.dart';
import '../finder/finder_start_flow.dart';
import '../voice_commands/voice_commands_screen.dart';

/// Home dashboard: "Ready to Find" / "Listening…" (reference board).
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  MonitoringController get _c => MonitoringController.instance;
  bool? _voiceModelInstalled;

  @override
  void initState() {
    super.initState();
    _checkVoiceModel();
  }

  Future<void> _checkVoiceModel() async {
    try {
      final installed = await FinderMonitoringService().isVoiceModelInstalled();
      if (mounted) setState(() => _voiceModelInstalled = installed);
    } catch (_) {
      if (mounted) setState(() => _voiceModelInstalled = false);
    }
  }

  Future<void> _setMethod(String method, bool value) async {
    if (_c.active) return;
    if (method == 'voice') {
      if (value && _voiceModelInstalled != true) {
        await Navigator.of(context).push(MaterialPageRoute<void>(
          builder: (_) => const VoiceCommandsScreen(),
        ));
        await _checkVoiceModel();
        if (mounted) setState(() {});
        return;
      }
      await _c.voiceSettings.setEnabled(value);
    } else {
      final p = _c.monitoringSettings.read();
      await _c.monitoringSettings.save(MonitoringPreferences(
        clapEnabled: method == 'clap' ? value : p.clapEnabled,
        whistleEnabled: method == 'whistle' ? value : p.whistleEnabled,
        clapSensitivity: p.clapSensitivity,
        whistleSensitivity: p.whistleSensitivity,
        autoStopMinutes: p.autoStopMinutes,
        quietHoursEnabled: p.quietHoursEnabled,
        quietStart: p.quietStart,
        quietEnd: p.quietEnd,
      ));
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: _c,
        builder: (context, _) {
          final active = _c.active;
          final monitoring = _c.monitoringSettings.read();
          final voiceOn = _c.voiceSettings.read().enabled;
          final clapOn = active ? _c.clapActive : monitoring.clapEnabled;
          final whistleOn =
              active ? _c.whistleActive : monitoring.whistleEnabled;
          final voiceShown = active ? _c.voiceActive : voiceOn;
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 14, 20, 28),
              children: [
                Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9),
                      child: Image.asset(
                        'assets/branding/vokey_icon_1024.png',
                        width: 34,
                        height: 34,
                        cacheWidth: 102,
                        semanticLabel: 'Vokey',
                      ),
                    ),
                    const SizedBox(width: 10),
                    const Text(
                      'Vokey',
                      style:
                          TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const Spacer(),
                    StatusPill(
                      active ? 'LISTENING' : 'OFF',
                      color: active ? VokeyTokens.success : VokeyTokens.warning,
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Center(child: _FinderRing(active: active, level: _c.level)),
                const SizedBox(height: 22),
                Text(
                  active ? 'Listening…' : 'Ready to Find',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w800,
                    color: active ? VokeyTokens.success : VokeyTokens.text,
                  ),
                ),
                const SizedBox(height: 6),
                if (active)
                  Center(child: _ElapsedText(since: _c.startedAt))
                else
                  const Text(
                    'Tap Start to begin listening\nfor claps, whistles or voice.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VokeyTokens.muted, height: 1.45),
                  ),
                if (active && _c.clapActive && _c.clapPattern > 1) ...[
                  const SizedBox(height: 10),
                  Center(
                    child: _ClapProgress(
                      count: _c.clapProgress,
                      required: _c.clapPattern,
                    ),
                  ),
                ],
                if (active &&
                    _c.snoozedUntil != null &&
                    _c.snoozedUntil!.isAfter(DateTime.now())) ...[
                  const SizedBox(height: 10),
                  const Center(
                    child: StatusPill('Alerts snoozed',
                        color: VokeyTokens.warning),
                  ),
                ],
                const SizedBox(height: 22),
                if (active)
                  DangerButton(label: 'Stop Finder', onPressed: _c.stop)
                else
                  GradientButton(
                    label: _c.busy ? 'Starting…' : 'Start Finder',
                    icon: Icons.play_arrow_rounded,
                    onPressed:
                        _c.busy ? null : () => FinderStartFlow.start(context),
                  ),
                if (_c.notice != null) ...[
                  const SizedBox(height: 14),
                  NoticeBanner(
                    message: _c.notice!,
                    color: VokeyTokens.warning,
                    onDismiss: _c.clearNotice,
                  ),
                ],
                const SizedBox(height: 22),
                Row(
                  children: [
                    Expanded(
                      child: _MethodTile(
                        icon: Icons.back_hand_rounded,
                        label: 'Clap',
                        on: clapOn,
                        locked: active,
                        onTap: () => _setMethod('clap', !clapOn),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MethodTile(
                        icon: Icons.sports_rounded,
                        label: 'Whistle',
                        on: whistleOn,
                        locked: active,
                        onTap: () => _setMethod('whistle', !whistleOn),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _MethodTile(
                        icon: Icons.mic_rounded,
                        label: 'Voice',
                        on: voiceShown,
                        locked: active,
                        onTap: () => _setMethod('voice', !voiceShown),
                      ),
                    ),
                  ],
                ),
                if (active)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Stop the finder to change detection methods.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: VokeyTokens.muted, fontSize: 12),
                    ),
                  ),
                const SizedBox(height: 18),
                SettingRow(
                  icon: Icons.science_rounded,
                  title: 'Finder Test',
                  subtitle: active
                      ? 'Stop the finder to run a test'
                      : 'Check your clap and whistle on this phone',
                  onTap: active
                      ? null
                      : () =>
                          Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => const ClapTestScreen(),
                          )),
                ),
                SettingRow(
                  icon: Icons.notifications_active_rounded,
                  iconColor: VokeyTokens.violet,
                  title: 'Alert Studio',
                  subtitle: 'Sound, vibration and flashlight',
                  onTap: () =>
                      Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (_) => const AlertStudioScreen(),
                  )),
                ),
                // Ads never show while monitoring or starting (product rule).
                if (!active && !_c.busy) ...[
                  const SizedBox(height: 6),
                  const Center(child: HomeBannerAd()),
                ],
              ],
            ),
          );
        },
      );
}

/// Gradient ring with live level bars; static when idle.
class _FinderRing extends StatelessWidget {
  const _FinderRing({required this.active, required this.level});
  final bool active;
  final ValueNotifier<double> level;

  @override
  Widget build(BuildContext context) {
    final color = active ? VokeyTokens.success : VokeyTokens.cyan;
    return Container(
      width: 190,
      height: 190,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [color.withValues(alpha: .16), VokeyTokens.background],
        ),
        border: Border.all(color: color.withValues(alpha: .8), width: 3),
        boxShadow: [
          BoxShadow(
              color: color.withValues(alpha: .28),
              blurRadius: 40,
              spreadRadius: 2),
        ],
      ),
      alignment: Alignment.center,
      child: active
          ? ValueListenableBuilder<double>(
              valueListenable: level,
              builder: (_, value, __) =>
                  LevelBars(level: value, bars: 15, height: 70),
            )
          : const Icon(Icons.graphic_eq_rounded,
              size: 84, color: VokeyTokens.cyan),
    );
  }
}

class _ElapsedText extends StatefulWidget {
  const _ElapsedText({required this.since});
  final DateTime? since;

  @override
  State<_ElapsedText> createState() => _ElapsedTextState();
}

class _ElapsedTextState extends State<_ElapsedText> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final since = widget.since;
    final d = since == null ? Duration.zero : DateTime.now().difference(since);
    return Text(
      formatDuration(d.isNegative ? Duration.zero : d),
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        fontFeatures: [FontFeature.tabularFigures()],
        color: VokeyTokens.muted,
      ),
    );
  }
}

class _ClapProgress extends StatelessWidget {
  const _ClapProgress({required this.count, required this.required});
  final int count;
  final int required;

  @override
  Widget build(BuildContext context) => Semantics(
        label: '$count of $required claps',
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < required; i++)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i < count ? VokeyTokens.cyan : VokeyTokens.cardBorder,
                ),
              ),
            const SizedBox(width: 8),
            Text(
              required == 2 ? 'Double clap' : 'Triple clap',
              style: const TextStyle(color: VokeyTokens.muted, fontSize: 12),
            ),
          ],
        ),
      );
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.label,
    required this.on,
    required this.locked,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool on;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Semantics(
        toggled: on,
        button: true,
        label: '$label detection',
        child: NeonCard(
          glow: on ? VokeyTokens.cyan : null,
          padding: const EdgeInsets.symmetric(vertical: 14),
          onTap: locked ? null : onTap,
          child: Column(
            children: [
              Icon(icon, color: on ? VokeyTokens.cyan : VokeyTokens.muted),
              const SizedBox(height: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                on ? 'On' : 'Off',
                style: TextStyle(
                  fontSize: 12,
                  color: on ? VokeyTokens.success : VokeyTokens.muted,
                ),
              ),
            ],
          ),
        ),
      );
}
