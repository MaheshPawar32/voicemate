import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// UMP consent gate and Google Mobile Ads initializer.
///
/// The banner widget must use [canRequestAds] before issuing any ad request.
/// Consent refresh and any required form complete before that gate opens.
class AdMobService extends ChangeNotifier {
  AdMobService._();

  static final AdMobService instance = AdMobService._();

  static const _consentFlowTimeout = Duration(seconds: 45);

  bool _initialized = false;
  bool _initializing = false;
  bool _canRequestAds = false;
  bool _privacyOptionsRequired = false;
  bool _mobileAdsInitialized = false;

  Future<void>? _initialization;
  Future<void>? _mobileAdsInitialization;

  bool get initialized => _initialized;
  bool get canRequestAds => _canRequestAds && _mobileAdsInitialized;
  bool get privacyOptionsRequired => _privacyOptionsRequired;

  Future<void> initialize() =>
      _initialization ??= _initialize();

  Future<void> _initialize() async {
    if (_initializing) return;
    _initializing = true;
    _canRequestAds = false;

    try {
      final consentFlow = Completer<void>();

      void finishConsentFlow() {
        if (!consentFlow.isCompleted) consentFlow.complete();
      }

      ConsentInformation.instance.requestConsentInfoUpdate(
        ConsentRequestParameters(),
        () async {
          try {
            final formFlow = Completer<void>();
            ConsentForm.loadAndShowConsentFormIfRequired((formError) {
              if (formError != null) {
                debugPrint(
                  'VoiceMate UMP form: ${formError.errorCode} ${formError.message}',
                );
              }
              if (!formFlow.isCompleted) formFlow.complete();
            });

            await formFlow.future.timeout(_consentFlowTimeout);
          } on TimeoutException {
            debugPrint('VoiceMate UMP consent form timed out; ads remain disabled.');
          } catch (error) {
            debugPrint('VoiceMate UMP form failed: $error');
          } finally {
            finishConsentFlow();
          }
        },
        (formError) {
          debugPrint(
            'VoiceMate consent update: ${formError.errorCode} ${formError.message}',
          );
          // UMP retains the previous session's consent state. Check that
          // state only after the refresh callback has reported its failure.
          finishConsentFlow();
        },
      );

      await consentFlow.future.timeout(_consentFlowTimeout);

      // UMP may return a valid prior-session consent state after a network
      // error, or an updated state after a form was shown. In both cases this
      // is intentionally checked only after the flow above has completed.
      await _refreshConsentStatus();
      if (_canRequestAds) {
        await _initializeMobileAds();
      }
    } on TimeoutException {
      debugPrint('VoiceMate UMP refresh timed out; ads remain disabled.');
      _canRequestAds = false;
      _privacyOptionsRequired = false;
    } catch (error) {
      debugPrint('VoiceMate ads initialization failed: $error');
      _canRequestAds = false;
    } finally {
      _initialized = true;
      _initializing = false;
      notifyListeners();
    }
  }

  Future<void> _refreshConsentStatus() async {
    _canRequestAds = await ConsentInformation.instance.canRequestAds();
    _privacyOptionsRequired =
        await ConsentInformation.instance.getPrivacyOptionsRequirementStatus() ==
            PrivacyOptionsRequirementStatus.required;
  }

  Future<void> _initializeMobileAds() async {
    if (_mobileAdsInitialized) return;
    final existing = _mobileAdsInitialization;
    if (existing != null) {
      await existing;
      return;
    }

    final initialization = MobileAds.instance.initialize().then((_) {
      _mobileAdsInitialized = true;
    });
    _mobileAdsInitialization = initialization;
    try {
      await initialization;
    } catch (_) {
      _mobileAdsInitialization = null;
      rethrow;
    }
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

    await _refreshConsentStatus();
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
