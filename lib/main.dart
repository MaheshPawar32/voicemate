import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/vokey_app.dart';
import 'services/telemetry_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(
      'Vokey flutter error: context=${details.context ?? 'n/a'} '
      'exception=${details.exceptionAsString()}',
    );
    // No-op until Firebase is ready or if the user turned crash reports off.
    TelemetryService.instance.recordFlutterError(details);
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Vokey uncaught error: $error');
    debugPrint('Vokey stack trace: $stack');
    TelemetryService.instance.recordError(error, stack, fatal: true);
    return true;
  };

  runApp(const VokeyApp());
}
