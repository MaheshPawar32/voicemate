import 'package:flutter_test/flutter_test.dart';
import 'package:vokey/services/clap_test_service.dart';

void main() {
  group('ClapTestEvent', () {
    test('parses normal microphone metrics', () {
      final event = ClapTestEvent.fromMap({
        'type': 'metrics',
        'rms': 950.5,
        'peak': 7200,
        'noise_floor': 310.0,
        'clap_count': 2,
        'is_clap': false,
      });
      expect(event.rms, 950.5);
      expect(event.peak, 7200);
      expect(event.noiseFloor, 310.0);
      expect(event.clapCount, 2);
      expect(event.isClap, isFalse);
      expect(event.error, isNull);
    });

    test('parses clap and error events', () {
      final clap = ClapTestEvent.fromMap(
          {'type': 'clap', 'clap_count': 1, 'is_clap': true});
      final error = ClapTestEvent.fromMap(
          {'type': 'error', 'message': 'Microphone unavailable'});
      expect(clap.isClap, isTrue);
      expect(clap.clapCount, 1);
      expect(error.error, 'Microphone unavailable');
    });
  });
}
