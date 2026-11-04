import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/voicemate_app.dart';
import '../../services/clap_test_service.dart';
import '../../services/history_repository.dart';

class ClapTestScreen extends StatefulWidget {
  const ClapTestScreen({super.key});
  @override
  State<ClapTestScreen> createState() => _ClapTestScreenState();
}

class _ClapTestScreenState extends State<ClapTestScreen> {
  final ClapTestService _service = ClapTestService();
  late final HistoryRepository _history;
  StreamSubscription<ClapTestEvent>? _subscription;
  ClapTestEvent _latest = const ClapTestEvent(
    rms: 0, peak: 0, noiseFloor: 0, clapCount: 0, isClap: false);
  bool _isRunning = false;
  bool _isBusy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _history = HistoryRepository(Hive.box<dynamic>('voicemate_settings'));
  }

  @override
  void dispose() {
    _subscription?.cancel();
    unawaited(_service.stop());
    super.dispose();
  }

  Future<void> _start() async {
    if (_isBusy || _isRunning) return;
    setState(() {
      _isBusy = true;
      _isRunning = false;
      _error = null;
      _latest = const ClapTestEvent(
        rms: 0, peak: 0, noiseFloor: 0, clapCount: 0, isClap: false);
    });
    try {
      final granted = await _service.requestMicrophonePermission();
      if (!granted) {
        throw const ClapTestException(
          'Microphone permission was not granted. You can enable it in Android app settings.');
      }
      await _subscription?.cancel();
      _subscription = _service.events.listen((event) {
        if (!mounted) return;
        setState(() {
          _latest = event;
          if (event.error != null || event.stopped) _isRunning = false;
          if (event.error != null) _error = event.error;
        });
        if (event.isClap) {
          unawaited(_history.record(
            eventType: 'clap_test_detected',
            metadata: {
              'clap_count': event.clapCount,
              'rms': event.rms,
              'peak': event.peak,
            },
          ));
        }
      }, onError: (Object error) {
        if (!mounted) return;
        setState(() { _error = error.toString(); _isRunning = false; });
      });
      if (mounted) setState(() => _isRunning = true);
      await _service.start();
    } catch (error) {
      await _subscription?.cancel();
      _subscription = null;
      await _service.stop();
      if (mounted) {
        setState(() { _isRunning = false; _error = error.toString(); });
      }
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _stop() async {
    await _subscription?.cancel();
    _subscription = null;
    await _service.stop();
    if (mounted) setState(() => _isRunning = false);
  }

  @override
  Widget build(BuildContext context) {
    final level = (_latest.rms / 10000).clamp(0.0, 1.0).toDouble();
    return Scaffold(
      appBar: AppBar(title: const Text('Clap detection lab')),
      body: SafeArea(child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 28),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: VoiceMateApp.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: VoiceMateApp.cyan.withValues(alpha: .18)),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.privacy_tip_outlined, color: VoiceMateApp.cyan),
                SizedBox(width: 12),
                Expanded(child: Text(
                  'This test listens only while this screen is open and the test is running. Audio is analysed in memory; VoiceMate does not save or upload recordings.',
                  style: TextStyle(height: 1.5))),
              ],
            ),
          ),
          const SizedBox(height: 26),
          Center(child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 154, height: 154,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _latest.isClap
                ? VoiceMateApp.cyan.withValues(alpha: .2)
                : VoiceMateApp.cyan.withValues(alpha: .06),
              border: Border.all(
                color: VoiceMateApp.cyan.withValues(
                  alpha: _isRunning ? .8 : .25),
                width: _isRunning ? 2 : 1),
              boxShadow: _latest.isClap ? [
                BoxShadow(
                  color: VoiceMateApp.cyan.withValues(alpha: .22),
                  blurRadius: 32, spreadRadius: 3),
              ] : null,
            ),
            child: Icon(
              _latest.isClap ? Icons.waving_hand_rounded
                : Icons.hearing_rounded,
              size: 66, color: VoiceMateApp.cyan),
          )),
          const SizedBox(height: 18),
          Text(
            _latest.isClap ? 'Clap detected!'
              : (_isRunning ? 'Listening for test claps' : 'Ready for a test'),
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w800)),
          const SizedBox(height: 7),
          Text(
            _isRunning
              ? 'Clap naturally at different distances. Watch the signal and count.'
              : 'Start the test, then clap once or several times near your phone.',
            textAlign: TextAlign.center,
            style: const TextStyle(color: VoiceMateApp.muted, height: 1.45)),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(17),
            decoration: BoxDecoration(
              color: VoiceMateApp.card,
              borderRadius: BorderRadius.circular(18)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  const Expanded(child: Text('Live microphone level',
                    style: TextStyle(fontWeight: FontWeight.w700))),
                  Text('${(level * 100).round()}%',
                    style: const TextStyle(
                      color: VoiceMateApp.cyan, fontWeight: FontWeight.w700)),
                ]),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: level, minHeight: 10,
                    backgroundColor: VoiceMateApp.surface,
                    color: VoiceMateApp.cyan)),
                const SizedBox(height: 18),
                Row(children: [
                  _Metric(label: 'CLAPS', value: '${_latest.clapCount}'),
                  _Metric(label: 'RMS', value: _latest.rms.toStringAsFixed(0)),
                  _Metric(label: 'PEAK', value: _latest.peak.toStringAsFixed(0)),
                ]),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF3A202B),
                borderRadius: BorderRadius.circular(14)),
              child: Text(_error!,
                style: const TextStyle(color: Color(0xFFFFA7B2)))),
          ],
          const SizedBox(height: 22),
          FilledButton.icon(
            onPressed: _isBusy ? null : (_isRunning ? _stop : _start),
            icon: Icon(_isBusy ? Icons.hourglass_top_rounded
              : (_isRunning ? Icons.stop_rounded : Icons.mic_rounded)),
            label: Text(_isBusy ? 'Please wait…'
              : (_isRunning ? 'Stop test' : 'Start clap test')),
            style: FilledButton.styleFrom(
              backgroundColor: _isRunning
                ? const Color(0xFFFF657A) : VoiceMateApp.cyan,
              foregroundColor: const Color(0xFF06111D),
              minimumSize: const Size.fromHeight(54)),
          ),
          const SizedBox(height: 14),
          const Text(
            'This is a foreground diagnostic test, not the background phone-finder feature. Detection accuracy must be validated on physical devices before wider use.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: VoiceMateApp.muted, fontSize: 12, height: 1.5)),
        ],
      )),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Expanded(child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(
        color: VoiceMateApp.muted, fontSize: 10, letterSpacing: 1.1)),
      const SizedBox(height: 5),
      Text(value, style: const TextStyle(
        fontSize: 18, fontWeight: FontWeight.w800)),
    ],
  ));
}
