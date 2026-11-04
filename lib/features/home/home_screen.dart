import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';
import '../../services/finder_monitoring_service.dart';
import '../../services/history_repository.dart';
import '../clap_detection/clap_test_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final FinderMonitoringService _monitoring = FinderMonitoringService();
  late final HistoryRepository _history;
  StreamSubscription<FinderMonitoringEvent>? _subscription;
  bool _isMonitoring = false;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _history = HistoryRepository(Hive.box<dynamic>('voicemate_settings'));
    _subscription = _monitoring.events.listen(_handleMonitoringEvent,
      onError: (Object error) {
        if (!mounted) return;
        setState(() {
          _error = error.toString();
          _isMonitoring = false;
          _isBusy = false;
        });
      });
    unawaited(_refreshStatus());
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _refreshStatus() async {
    try {
      final active = await _monitoring.isActive();
      if (mounted) setState(() => _isMonitoring = active);
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  void _handleMonitoringEvent(FinderMonitoringEvent event) {
    if (!mounted) return;
    switch (event.type) {
      case 'service_started':
        setState(() {
          _isMonitoring = true;
          _isBusy = false;
          _error = null;
        });
        break;
      case 'service_stopped':
        setState(() {
          _isMonitoring = false;
          _isBusy = false;
        });
        break;
      case 'service_error':
        setState(() {
          _isMonitoring = false;
          _isBusy = false;
          _error = event.message ?? 'Monitoring stopped unexpectedly.';
        });
        break;
      case 'detection':
        if (event.eventType == 'clap' || event.eventType == 'whistle') {
          unawaited(_history.record(
            eventType: event.eventType == 'clap'
                ? 'clap_monitor_detected'
                : 'whistle_monitor_detected',
            metadata: {
              'clap_count': event.clapCount,
              'whistle_count': event.whistleCount,
              'whistle_frequency_hz': event.whistleFrequencyHz,
              'rms': event.rms,
              'peak': event.peak,
            },
          ));
        }
        break;
    }
  }

  Future<void> _toggleMonitoring() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
      _error = null;
    });
    try {
      if (_isMonitoring) {
        await _monitoring.stop();
        if (mounted) {
          setState(() {
            _isMonitoring = false;
            _isBusy = false;
          });
        }
      } else {
        final granted = await _monitoring.requestMicrophonePermission();
        if (!granted) {
          throw const FinderMonitoringException(
            'Microphone permission is required. Enable it in Android settings to start monitoring.');
        }
        await _monitoring.start();
        if (mounted) {
          setState(() {
            _isMonitoring = true;
            _isBusy = false;
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
          _isBusy = false;
          _isMonitoring = false;
        });
      }
    }
  }

  void _openClapTest() {
    if (_isMonitoring) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const ClapTestScreen()));
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 28),
      children: [
        const Text('VoiceMate', style: TextStyle(
          fontSize: 25, fontWeight: FontWeight.w800)),
        const SizedBox(height: 20),
        Row(children: [
          const Expanded(child: Text('Your phone,\nnever lost.',
            style: TextStyle(fontSize: 27, height: 1.15,
              fontWeight: FontWeight.w800))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
            decoration: BoxDecoration(
              color: _isMonitoring
                ? const Color(0xFF17382F) : const Color(0xFF302A20),
              borderRadius: BorderRadius.circular(30)),
            child: Row(children: [
              Icon(Icons.circle, size: 8,
                color: _isMonitoring
                  ? const Color(0xFF38D99A) : const Color(0xFFFFBE55)),
              const SizedBox(width: 7),
              Text(_isMonitoring ? 'MONITORING ON' : 'MONITORING OFF',
                style: const TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700)),
            ]),
          ),
        ]),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(23),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF18365A), Color(0xFF111D32)],
              begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(26),
            border: Border.all(
              color: VoiceMateApp.cyan.withValues(alpha: .25)),
          ),
          child: Column(children: [
            Container(
              width: 112, height: 112,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: VoiceMateApp.cyan.withValues(alpha: .09),
                border: Border.all(
                  color: VoiceMateApp.cyan.withValues(alpha: .35),
                  width: 1.5)),
              child: Icon(
                _isMonitoring ? Icons.hearing_rounded
                  : Icons.graphic_eq_rounded,
                size: 58, color: VoiceMateApp.cyan)),
            const SizedBox(height: 17),
            Text(_isMonitoring ? 'Clap & whistle finder is active' : 'Finder is paused',
              style: const TextStyle(
                fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text(
              _isMonitoring
                ? 'VoiceMate is listening for clap and sustained whistle-like tones. A detection triggers a sound and vibration alert.'
                : 'Start monitoring to listen for clap and sustained whistle-like tones while the Android foreground notification is visible.',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: VoiceMateApp.muted, height: 1.45)),
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _isBusy ? null : _toggleMonitoring,
              icon: Icon(_isBusy
                ? Icons.hourglass_top_rounded
                : (_isMonitoring ? Icons.stop_rounded : Icons.hearing_rounded)),
              label: Text(_isBusy ? 'Please wait…'
                : (_isMonitoring ? 'Stop monitoring' : 'Start clap finder')),
              style: FilledButton.styleFrom(
                backgroundColor: _isMonitoring
                  ? const Color(0xFFFF657A) : VoiceMateApp.cyan,
                foregroundColor: const Color(0xFF06111D),
                minimumSize: const Size.fromHeight(50)),
            ),
          ]),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: const Color(0xFF3A202B),
              borderRadius: BorderRadius.circular(14)),
            child: Text(_error!,
              style: const TextStyle(color: Color(0xFFFFA7B2))),
          ),
        ],
        const SizedBox(height: 25),
        const Text('Available tools', style: TextStyle(
          fontSize: 19, fontWeight: FontWeight.w800)),
        const SizedBox(height: 13),
        Card(
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: _isMonitoring ? null : _openClapTest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                const Icon(Icons.back_hand_rounded,
                  color: VoiceMateApp.cyan, size: 30),
                const SizedBox(width: 14),
                const Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Clap Detection Diagnostic',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                    SizedBox(height: 4),
                    Text('Foreground microphone signal test',
                      style: TextStyle(
                        color: VoiceMateApp.muted, fontSize: 12)),
                  ],
                )),
                Icon(_isMonitoring
                  ? Icons.lock_outline_rounded
                  : Icons.chevron_right_rounded,
                  color: VoiceMateApp.muted),
              ]),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoiceMateApp.surface,
            borderRadius: BorderRadius.circular(18)),
          child: const Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.shield_outlined, color: VoiceMateApp.cyan),
              SizedBox(width: 12),
              Expanded(child: Text(
                'Privacy first\nMicrophone monitoring starts only after you tap Start and grant permission. Audio is processed on this device; VoiceMate does not save recordings.',
                style: TextStyle(height: 1.45))),
            ],
          ),
        ),
      ],
    ),
  );
}
