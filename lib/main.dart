import 'dart:ui';

import 'package:flutter/material.dart';

import 'app/vokey_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint(
      'Vokey flutter error: context=${details.context ?? 'n/a'} '
      'exception=${details.exceptionAsString()}',
    );
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('Vokey uncaught error: $error');
    debugPrint('Vokey stack trace: $stack');
    return true;
  };

  runApp(const VokeyApp());
}
