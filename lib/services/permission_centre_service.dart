import 'package:flutter/services.dart';

class PermissionStatusSnapshot {
  const PermissionStatusSnapshot({
    required this.microphoneGranted,
    required this.notificationPermissionGranted,
    required this.notificationsEnabled,
    required this.cameraGranted,
    required this.apiLevel,
  });

  final bool microphoneGranted;
  final bool notificationPermissionGranted;
  final bool notificationsEnabled;
  final bool cameraGranted;
  final int apiLevel;

  bool get monitoringNotificationReady =>
      notificationPermissionGranted && notificationsEnabled;

  factory PermissionStatusSnapshot.fromMap(Map<dynamic, dynamic> map) =>
      PermissionStatusSnapshot(
        microphoneGranted: map['microphone_granted'] == true,
        notificationPermissionGranted:
            map['notification_permission_granted'] == true,
        notificationsEnabled: map['notifications_enabled'] == true,
        cameraGranted: map['camera_granted'] == true,
        apiLevel: (map['api_level'] as num?)?.toInt() ?? 0,
      );
}

class PermissionCentreService {
  static const MethodChannel _methods =
      MethodChannel('com.dev.vokey/monitoring/methods');
  static const MethodChannel _microphoneMethods =
      MethodChannel('com.dev.vokey/audio_test/methods');

  Future<PermissionStatusSnapshot> readStatus() async {
    try {
      final result = await _methods.invokeMapMethod<dynamic, dynamic>(
        'getPermissionStatus',
      );
      if (result == null) {
        throw const PermissionCentreException(
          'Android did not return permission information.',
        );
      }
      return PermissionStatusSnapshot.fromMap(result);
    } on PlatformException catch (error) {
      throw PermissionCentreException(
        error.message ?? 'Could not read Android permission status.',
      );
    } on MissingPluginException {
      throw const PermissionCentreException(
        'Android permission integration is not available.',
      );
    }
  }

  Future<bool> requestMicrophone() async {
    try {
      return await _microphoneMethods.invokeMethod<bool>(
            'requestMicrophonePermission',
          ) ??
          false;
    } on PlatformException catch (error) {
      throw PermissionCentreException(
        error.message ?? 'Could not request microphone permission.',
      );
    }
  }

  Future<bool> requestCamera() async {
    try {
      return await _methods.invokeMethod<bool>(
            'requestCameraPermission',
          ) ??
          false;
    } on PlatformException catch (error) {
      throw PermissionCentreException(
        error.message ?? 'Could not request camera permission.',
      );
    }
  }

  Future<bool> requestNotifications() async {
    try {
      return await _methods.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on PlatformException catch (error) {
      throw PermissionCentreException(
        error.message ?? 'Could not request notification permission.',
      );
    }
  }

  Future<void> openAppSettings() async {
    try {
      await _methods.invokeMethod<void>('openAppSettings');
    } on PlatformException catch (error) {
      throw PermissionCentreException(
        error.message ?? 'Could not open Android settings.',
      );
    }
  }
}

class PermissionCentreException implements Exception {
  const PermissionCentreException(this.message);
  final String message;
  @override
  String toString() => message;
}
