import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP consent gate and Google Mobile Ads initializer.
///
/// Every ad request must be gated by [canRequestAds]. Consent is refreshed
/// on every app launch; ad loading is independent of finder microphone work.
class AdMobService extends ChangeNotifier {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  bool _initialized = false;
  bool _initializing = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _mobileAdsInitialized = false;

  bool get initialized => _initialized;
  bool get canRequestAds => _canRequestAds && _mobileAdsInitialized;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<void>? _initialization;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;

    final updateComplete = Completer<void>();
    void completeUpdate() {
      if (!updateComplete.isCompleted) updateComplete.complete();
    }

    try {
      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            await ConsentForm.loadAndShowConsentFormIfRequired(
              (formError) {
                if (formError != null) {
                  debugPrint(
                    'VoiceMate UMP form: ${formError.errorCode} ${formError.message}',
                  );
                }
              },
            );
          } catch (error) {
            debugPrint('VoiceMate UMP form failed: $error');
          } finally {
            completeUpdate();
          }
        },
        (formError) {
          debugPrint(
            'VoiceMate consent update: ${formError.errorCode} ${formError.message}',
          );
          completeUpdate();
        },
      );

      // Startup does not await this service, so wait for UMP's callback rather
      // than proceeding with stale consent if a required form takes longer.

      _canRequestAds =
          await ConsentInformation.instance.canRequestAds();
      _privacyOptionsRequired =
          await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
              PrivacyOptionsRequirementStatus.required;

      if (_canRequestAds) {
        await _initializeMobileAds();
      }
    } catch (error) {
      debugPrint('VoiceMate ads initialization failed: $error');
      // If UMP or ad initialization fails, ads remain disabled and the app
      // continues working normally.
      _canRequestAds = false;
    } finally {
      _initialized = true;
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _initializeMobileAds() async {
    if (_mobileAdsInitialized) return;
    await MobileAds.instance.initialize();
    _mobileAdsInitialized = true;
  }

  Future<void> showPrivacyOptions() async {
    if (!_initialized) await initialize();
    if (!_privacyOptionsRequired) return;

    await ConsentForm.showPrivacyOptionsForm((formError) {
      if (formError != null) {
        debugPrint(
          'VoiceMate privacy options: ${formError.errorCode} ${formError.message}',
        );
      }
    });

    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _privacyOptionsRequired =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;

    if (_canRequestAds) {
      try {
        await _initializeMobileAds();
      } catch (error) {
        debugPrint('VoiceMate ad SDK init after consent failed: $error');
        _canRequestAds = false;
      }
    }
    notifyListeners();
  }
}
