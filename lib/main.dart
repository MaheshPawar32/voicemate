import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import 'app/voicemate_app.dart';
import 'services/admob_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();
  await Hive.openBox<dynamic>('voicemate_settings');
  runApp(const VoiceMateApp());
  unawaited(AdMobService.instance.initialize());
}
