import 'package:flutter_test/flutter_test.dart';
import 'package:vokey/core/ads/ad_ids.dart';

void main() {
  test('non-release builds never request production ad units', () {
    // flutter test runs in debug mode.
    expect(AdIds.usesProductionUnits, isFalse);
    for (final id in [AdIds.banner, AdIds.interstitial, AdIds.native]) {
      expect(id, startsWith('ca-app-pub-3940256099942544/'),
          reason: 'Google test publisher ID expected outside release');
    }
  });
}
