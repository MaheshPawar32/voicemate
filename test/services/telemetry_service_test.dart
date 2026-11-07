import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vokey/services/telemetry_service.dart';

void main() {
  group('sanitize', () {
    test('keeps numbers, booleans and short enum strings', () {
      final out = TelemetryService.sanitize({
        'method': 'clap',
        'clap_pattern': 2,
        'ratio': 0.5,
        'alert_played': true,
        'format': 'm4a',
      });
      expect(out, {
        'method': 'clap',
        'clap_pattern': 2,
        'ratio': 0.5,
        'alert_played': 1,
        'format': 'm4a',
      });
    });

    test('drops free text, file names, long values and bad keys', () {
      final out = TelemetryService.sanitize({
        'name': 'My Doorbell Sound', // spaces/capitals = free text
        'file': '../secret/path.mp3',
        'phrase': 'find my phone please',
        'long': 'a' * 41,
        'Bad-Key': 'clap',
        'nested': {'x': 1},
        'nothing': null,
      });
      expect(out, isEmpty);
    });
  });

  test('duration is bucketed, never exact', () {
    expect(
        TelemetryService.durationBucket(const Duration(seconds: 30)), 'lt_1m');
    expect(
        TelemetryService.durationBucket(const Duration(minutes: 5)), '1_10m');
    expect(
        TelemetryService.durationBucket(const Duration(minutes: 45)), '30_60m');
    expect(TelemetryService.durationBucket(const Duration(hours: 5)), 'gt_3h');
  });

  test('every allow-listed name is a valid Analytics event name', () {
    for (final name in TelemetryService.allowedEvents) {
      expect(RegExp(r'^[a-z][a-z0-9_]{0,39}$').hasMatch(name), isTrue,
          reason: name);
    }
  });

  test('calls before Firebase is ready are silent no-ops', () {
    final t = TelemetryService.instance;
    expect(t.isReady, isFalse);
    t.log('phone_found', {'method': 'clap'});
    t.screen('home');
    t.recordError(StateError('x'), StackTrace.current);
    t.setCrashKey('monitoring_active', true);
    t.recordFlutterError(FlutterErrorDetails(exception: StateError('y')));
  });

  test('unknown events are rejected in debug builds', () {
    expect(
      () => TelemetryService.instance.log('user_typed_text'),
      throwsA(isA<AssertionError>()),
    );
  });
}
