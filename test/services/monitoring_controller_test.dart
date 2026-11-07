import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:vokey/services/finder_monitoring_service.dart';
import 'package:vokey/services/history_repository.dart';
import 'package:vokey/services/monitoring_controller.dart';

FinderMonitoringEvent event(Map<String, dynamic> map) =>
    FinderMonitoringEvent.fromMap(map);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Box<dynamic> box;
  late MonitoringController c;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('vokey_controller_');
    Hive.init(dir.path);
    box = await Hive.openBox<dynamic>('controller_test');
    c = MonitoringController(box); // not attached: no platform channel
  });

  tearDown(() async {
    c.dispose();
    await box.close();
    await Hive.deleteFromDisk();
    await dir.delete(recursive: true);
  });

  test('applies the native status snapshot', () {
    final started = DateTime(2026, 11, 7, 10).millisecondsSinceEpoch;
    c.applyStatus({
      'schema_version': 1,
      'active': true,
      'started_at_ms': started,
      'clap_enabled': true,
      'whistle_enabled': false,
      'voice_enabled': true,
      'clap_pattern': 2,
      'alert_active': false,
    });
    expect(c.active, isTrue);
    expect(c.startedAt!.millisecondsSinceEpoch, started);
    expect(c.clapActive, isTrue);
    expect(c.whistleActive, isFalse);
    expect(c.voiceActive, isTrue);
    expect(c.clapPattern, 2);
  });

  test('legacy bool-only status is treated as inactive details', () {
    c.applyStatus({'active': false});
    expect(c.active, isFalse);
    expect(c.startedAt, isNull);
  });

  test('a detection records metadata-only history and notifies the UI',
      () async {
    final seen = <DetectionInfo>[];
    final sub = c.detections.listen(seen.add);
    await c.handleEvent(event({
      'type': 'detection',
      'event_type': 'clap',
      'alert_played': true,
      'suppressed_reason': '',
      'clap_pattern': 2,
      'rms': 1234.0,
      'timestamp': DateTime(2026, 11, 7, 9).millisecondsSinceEpoch,
    }));
    await Future<void>.delayed(Duration.zero);
    final saved = c.history.readAll().single;
    expect(saved['event_type'], HistoryRepository.clapDetected);
    final meta = saved['metadata'] as Map;
    expect(meta['clap_pattern'], 2);
    expect(meta.containsKey('rms'), isFalse, reason: 'no signal data kept');
    expect(c.alertActive, isTrue);
    expect(seen.single.eventType, 'clap');
    expect(seen.single.historyId, saved['id']);
    await sub.cancel();
  });

  test('suppressed detections are logged but do not ring', () async {
    await c.handleEvent(event({
      'type': 'detection',
      'event_type': 'whistle',
      'alert_played': false,
      'suppressed_reason': 'pocket_mode',
    }));
    expect(c.alertActive, isFalse);
    expect(c.lastDetection!.suppressedReason, 'pocket_mode');
    final meta = c.history.readAll().single['metadata'] as Map;
    expect(meta['suppressed_reason'], 'pocket_mode');
  });

  test('stop records a monitoring session and resets state', () async {
    c.applyStatus({'active': true, 'started_at_ms': 1});
    await c.handleEvent(event({
      'type': 'service_stopped',
      'reason': 'user_stop',
      'duration_ms': 120000,
    }));
    expect(c.active, isFalse);
    final s = c.history.readAll().single;
    expect(s['event_type'], HistoryRepository.monitoringSession);
    expect((s['metadata'] as Map)['duration_ms'], 120000);
  });

  test('battery auto-stop explains why monitoring ended', () async {
    c.applyStatus({'active': true, 'started_at_ms': 1});
    await c.handleEvent(event({
      'type': 'service_auto_stopped',
      'reason': 'battery_low',
      'duration_ms': 5000,
    }));
    expect(c.active, isFalse);
    expect(c.notice, contains('battery'));
  });

  test('clap progress and level updates', () async {
    await c.handleEvent(
        event({'type': 'clap_progress', 'count': 1, 'required': 3}));
    expect(c.clapProgress, 1);
    // ~-20.8 dBFS on a -60..0 dB meter.
    await c.handleEvent(event({'type': 'level', 'rms': 3000.0}));
    expect(c.level.value, closeTo(.653, .01));
    await c.handleEvent(event({'type': 'level', 'rms': 0.0}));
    expect(c.level.value, 0);
  });
}
