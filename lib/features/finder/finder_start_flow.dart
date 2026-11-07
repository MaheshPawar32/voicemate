import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/finder_monitoring_service.dart';
import '../../services/monitoring_controller.dart';

/// The only path that starts microphone monitoring from the UI:
/// disclosure → microphone → notifications → (camera if flash alerts) → start.
class FinderStartFlow {
  static const disclosureKey = 'mic_disclosure_acknowledged';

  static Future<void> start(BuildContext context) async {
    final controller = MonitoringController.instance;
    if (controller.busy || controller.active) return;
    final service = controller.service;
    HapticFeedback.mediumImpact();

    if (!await confirmDisclosure(context)) return;
    try {
      if (!await service.requestMicrophonePermission()) {
        throw const FinderMonitoringException(
          'Microphone permission is required. Enable it for Vokey in Android settings to start monitoring.',
        );
      }
      if (!await service.requestNotificationPermission()) {
        throw const FinderMonitoringException(
          'Notifications are required so the active-monitoring notification and its Stop action stay visible. Enable notifications for Vokey in Android settings.',
        );
      }
      if (controller.alertSettings.read().flashlightEnabled &&
          !await service.requestCameraPermission()) {
        throw const FinderMonitoringException(
          'Camera permission is required for flashlight alerts. Turn flashlight off in Alert Studio or allow camera access.',
        );
      }
    } on FinderMonitoringException catch (error) {
      controller.showNotice(error.message);
      return;
    }
    await controller.start();
  }

  /// Prominent disclosure shown once, before the first microphone request.
  static Future<bool> confirmDisclosure(BuildContext context) async {
    final box = MonitoringController.instance.box;
    if (box.get(disclosureKey, defaultValue: false) == true) return true;
    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Microphone access for phone finder'),
        content: const SingleChildScrollView(
          child: Text(
            'Vokey uses the microphone to detect claps, whistle-like tones and supported voice commands while monitoring is on. Audio is analysed on this device in temporary memory. Vokey does not save recordings or upload microphone audio.\n\n'
            'While monitoring, Android shows an ongoing notification with a Stop action. You can stop from the app, that notification, the Quick Settings tile or the widget.\n\n'
            'Only continue if you agree to this microphone use.',
            style: TextStyle(height: 1.5),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Not now'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Continue'),
          ),
        ],
      ),
    );
    if (accepted == true) {
      await box.put(disclosureKey, true);
      return true;
    }
    return false;
  }
}
