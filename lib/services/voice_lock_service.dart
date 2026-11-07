import 'package:flutter/services.dart';

class VoiceLockService {
  static const MethodChannel _channel =
      MethodChannel('com.dev.vokey/monitoring/methods');

  Future<bool> isAdminActive() async {
    try {
      return await _channel.invokeMethod<bool>('getLockAdminStatus') ?? false;
    } on PlatformException catch (error) {
      throw VoiceLockException(
          error.message ?? 'Could not read screen-lock permission status.');
    } on MissingPluginException {
      throw const VoiceLockException(
          'Android screen-lock integration is not available.');
    }
  }

  Future<void> requestActivation() async {
    try {
      await _channel.invokeMethod<void>('requestLockAdminActivation');
    } on PlatformException catch (error) {
      throw VoiceLockException(
          error.message ?? 'Could not request screen-lock permission.');
    }
  }

  /// Removes Vokey's device-admin permission (needed before uninstalling).
  Future<void> deactivate() async {
    try {
      await _channel.invokeMethod<bool>('deactivateLockAdmin');
    } on PlatformException catch (error) {
      throw VoiceLockException(
          error.message ?? 'Could not remove the screen-lock permission.');
    }
  }

  Future<void> lockNow() async {
    try {
      final locked = await _channel.invokeMethod<bool>('lockDeviceNow');
      if (locked != true) {
        throw const VoiceLockException(
            'Android did not confirm the lock action.');
      }
    } on PlatformException catch (error) {
      throw VoiceLockException(error.message ?? 'Could not lock this device.');
    }
  }
}

class VoiceLockException implements Exception {
  const VoiceLockException(this.message);
  final String message;
  @override
  String toString() => message;
}
