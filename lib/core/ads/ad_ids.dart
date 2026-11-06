import 'package:flutter/foundation.dart';

/// AdMob unit IDs.
///
/// Release builds use Vokey's production units; debug/profile builds use
/// Google's public test units, because requesting live ads during development
/// is treated as invalid traffic and can suspend the AdMob account.
///
/// Overrides (e.g. internal-testing release builds):
///   --dart-define=ADMOB_USE_TEST_IDS=true
///   --dart-define=ADMOB_BANNER_ID=... (also _INTERSTITIAL_ID, _NATIVE_ID)
///
/// The matching AdMob *App* ID is set per build type in
/// android/app/build.gradle.kts (manifest placeholder `admobAppId`).
class AdIds {
  AdIds._();

  // Production units (AdMob app ca-app-pub-3548177810801627~3283313382).
  static const _prodBanner = 'ca-app-pub-3548177810801627/1046006167';
  static const _prodInterstitial = 'ca-app-pub-3548177810801627/4331691239';
  static const _prodNative = 'ca-app-pub-3548177810801627/9471291092';

  // Google sample units: https://developers.google.com/admob/android/test-ads
  static const _testBanner = 'ca-app-pub-3940256099942544/6300978111';
  static const _testInterstitial = 'ca-app-pub-3940256099942544/1033173712';
  static const _testNative = 'ca-app-pub-3940256099942544/2247696110';

  static const _forceTest = bool.fromEnvironment('ADMOB_USE_TEST_IDS');
  static const _bannerOverride = String.fromEnvironment('ADMOB_BANNER_ID');
  static const _interstitialOverride =
      String.fromEnvironment('ADMOB_INTERSTITIAL_ID');
  static const _nativeOverride = String.fromEnvironment('ADMOB_NATIVE_ID');

  /// True when production units are in use.
  static bool get usesProductionUnits => kReleaseMode && !_forceTest;

  static String _pick(String override, String prod, String test) {
    if (override.isNotEmpty) return override;
    return usesProductionUnits ? prod : test;
  }

  static String get banner => _pick(_bannerOverride, _prodBanner, _testBanner);

  static String get interstitial =>
      _pick(_interstitialOverride, _prodInterstitial, _testInterstitial);

  static String get native => _pick(_nativeOverride, _prodNative, _testNative);
}
