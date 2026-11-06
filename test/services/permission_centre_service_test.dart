import 'package:flutter_test/flutter_test.dart';
import 'package:vokey/services/permission_centre_service.dart';

void main() {
  test('identifies monitoring notification readiness', () {
    final ready = PermissionStatusSnapshot.fromMap({
      'microphone_granted': true,
      'notification_permission_granted': true,
      'notifications_enabled': true,
      'camera_granted': true,
      'api_level': 36,
    });
    expect(ready.microphoneGranted, isTrue);
    expect(ready.monitoringNotificationReady, isTrue);
    expect(ready.cameraGranted, isTrue);

    final hidden = PermissionStatusSnapshot.fromMap({
      'microphone_granted': true,
      'notification_permission_granted': true,
      'notifications_enabled': false,
      'api_level': 32,
    });
    expect(hidden.monitoringNotificationReady, isFalse);
    expect(hidden.cameraGranted, isFalse);
  });

  test('defaults missing permission fields to unavailable', () {
    final status = PermissionStatusSnapshot.fromMap({});
    expect(status.microphoneGranted, isFalse);
    expect(status.notificationPermissionGranted, isFalse);
    expect(status.notificationsEnabled, isFalse);
    expect(status.cameraGranted, isFalse);
    expect(status.apiLevel, 0);
  });
}
