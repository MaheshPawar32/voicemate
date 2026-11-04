import 'package:flutter_test/flutter_test.dart';
import 'package:voicemate/services/permission_centre_service.dart';

void main() {
  test('identifies monitoring notification readiness', () {
    final ready = PermissionStatusSnapshot.fromMap({
      'microphone_granted': true,
      'notification_permission_granted': true,
      'notifications_enabled': true,
      'api_level': 36,
    });
    expect(ready.microphoneGranted, isTrue);
    expect(ready.monitoringNotificationReady, isTrue);

    final hidden = PermissionStatusSnapshot.fromMap({
      'microphone_granted': true,
      'notification_permission_granted': true,
      'notifications_enabled': false,
      'api_level': 32,
    });
    expect(hidden.monitoringNotificationReady, isFalse);
  });

  test('defaults missing permission fields to unavailable', () {
    final status = PermissionStatusSnapshot.fromMap({});
    expect(status.microphoneGranted, isFalse);
    expect(status.notificationPermissionGranted, isFalse);
    expect(status.notificationsEnabled, isFalse);
    expect(status.apiLevel, 0);
  });
}
