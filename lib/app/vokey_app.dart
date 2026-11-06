import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../services/admob_service.dart';
import 'vokey_splash.dart';

import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';

class AppStartupState {
  const AppStartupState._({
    this.settingsBox,
    this.errorMessage,
    this.isLoading = false,
  });

  factory AppStartupState.loading() => const AppStartupState._(isLoading: true);

  factory AppStartupState.ready(Box<dynamic> settingsBox) =>
      AppStartupState._(settingsBox: settingsBox);

  factory AppStartupState.failed(String message) =>
      AppStartupState._(errorMessage: message);

  final Box<dynamic>? settingsBox;
  final String? errorMessage;
  final bool isLoading;

  bool get isReady => settingsBox != null && !isLoading;
  bool get hasError => errorMessage != null;

  static const settingsBoxName = 'vokey_settings';

  /// Deletes only the settings box (by name, so it works even when the box
  /// failed to open). Requires Hive to have been initialised.
  static Future<void> resetSettingsStorage() async {
    if (Hive.isBoxOpen(settingsBoxName)) {
      await Hive.box<dynamic>(settingsBoxName).close();
    }
    await Hive.deleteBoxFromDisk(settingsBoxName);
  }

  /// Opens local storage. [initHive] is injectable so tests can point Hive
  /// at a temporary directory instead of the platform documents folder.
  static Future<AppStartupState> initialize({
    Future<void> Function()? initHive,
  }) async {
    var stage = 'hive_init';
    try {
      await (initHive ?? Hive.initFlutter)();
      stage = 'open_settings_box';
      final settingsBox = await Hive.openBox<dynamic>(settingsBoxName);
      return AppStartupState.ready(settingsBox);
    } catch (error, stackTrace) {
      // Diagnostics: stage + exception type only. No settings values.
      debugPrint(
        'Vokey startup diagnostics: stage=$stage '
        'error=${error.runtimeType}',
      );
      if (kDebugMode) debugPrint('Vokey startup stack: $stackTrace');
      return AppStartupState.failed(
        'Vokey could not access local storage. This can happen when the '
        'device storage is unavailable or the existing settings file is '
        'corrupted. Try again or reset local data to recover.',
      );
    }
  }
}

class VokeyApp extends StatefulWidget {
  const VokeyApp({super.key, this.startupOverride});

  final AppStartupState? startupOverride;

  static const background = Color(0xFF0B1020);
  static const surface = Color(0xFF131B2E);
  static const card = Color(0xFF19243A);
  static const cyan = Color(0xFF26D9E8);
  static const violet = Color(0xFF7777FF);
  static const muted = Color(0xFF9BA9BE);

  @override
  State<VokeyApp> createState() => _VokeyAppState();
}

class _VokeyAppState extends State<VokeyApp> {
  AppStartupState _startup = AppStartupState.loading();

  @override
  void initState() {
    super.initState();
    if (widget.startupOverride != null) {
      _startup = widget.startupOverride!;
      return;
    }
    _initialize();
  }

  static const minimumSplashDuration = Duration(milliseconds: 1400);

  Future<void> _initialize() async {
    // Keep the animated splash up long enough for its entrance to finish;
    // storage init runs in parallel, so this never delays a slow start.
    final results = await Future.wait<Object?>([
      AppStartupState.initialize(),
      Future<void>.delayed(minimumSplashDuration),
    ]);
    final next = results.first! as AppStartupState;
    if (!mounted) return;
    setState(() => _startup = next);
  }

  Future<void> _resetLocalData() async {
    try {
      // deleteFromDisk() only removes *open* boxes; after a failed open the
      // settings box is not open, so delete it by name.
      await AppStartupState.resetSettingsStorage();
    } catch (error) {
      debugPrint('Vokey startup reset failed: ${error.runtimeType}');
    }
    if (!mounted) return;
    setState(() => _startup = AppStartupState.loading());
    await _initialize();
  }

  @override
  Widget build(BuildContext context) => AnimatedSwitcher(
        duration: const Duration(milliseconds: 450),
        switchInCurve: Curves.easeOut,
        child: KeyedSubtree(
          key: ValueKey(_startup.isLoading
              ? 'loading'
              : (_startup.hasError ? 'error' : 'ready')),
          child: _buildForState(context),
        ),
      );

  Widget _buildForState(BuildContext context) {
    if (_startup.isLoading) {
      return const _StartupLoadingScreen();
    }
    if (_startup.hasError) {
      return _StartupRecoveryScreen(
        errorMessage:
            _startup.errorMessage ?? 'Vokey could not complete startup.',
        onRetry: _initialize,
        onReset: _resetLocalData,
      );
    }
    return MaterialApp(
      title: 'Vokey',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: VokeyApp.background,
        colorScheme: const ColorScheme.dark(
          primary: VokeyApp.cyan,
          secondary: VokeyApp.violet,
          surface: VokeyApp.surface,
          error: Color(0xFFFF657A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: VokeyApp.background,
          foregroundColor: Color(0xFFF4F7FF),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: VokeyApp.card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: VokeyApp.surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: _AppEntry(settingsBox: _startup.settingsBox!),
    );
  }
}

class _StartupLoadingScreen extends StatelessWidget {
  const _StartupLoadingScreen();

  @override
  Widget build(BuildContext context) => const MaterialApp(
        title: 'Vokey',
        debugShowCheckedModeBanner: false,
        home: VokeySplash(status: 'Preparing your local settings…'),
      );
}

class _StartupRecoveryScreen extends StatelessWidget {
  const _StartupRecoveryScreen({
    required this.errorMessage,
    required this.onRetry,
    required this.onReset,
  });

  final String errorMessage;
  final Future<void> Function() onRetry;
  final Future<void> Function() onReset;

  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(useMaterial3: true),
        home: Scaffold(
          backgroundColor: VokeyApp.background,
          body: SafeArea(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Card(
                  color: VokeyApp.surface,
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.storage_rounded,
                          size: 56,
                          color: Color(0xFFFFBE55),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Vokey needs a quick recovery',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          errorMessage,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: VokeyApp.muted,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 24),
                        FilledButton.icon(
                          onPressed: () => onRetry(),
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Try again'),
                        ),
                        const SizedBox(height: 12),
                        TextButton.icon(
                          onPressed: () => onReset(),
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: const Text('Reset local data'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}

class _AppEntry extends StatefulWidget {
  const _AppEntry({required this.settingsBox});

  final Box<dynamic> settingsBox;

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late final Box<dynamic> _settings;

  @override
  void initState() {
    super.initState();
    _settings = widget.settingsBox;
  }

  Future<void> _completeOnboarding() async {
    await _settings.put('onboarding_complete', true);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final complete =
        _settings.get('onboarding_complete', defaultValue: false) == true;
    return complete
        ? const VokeyShell()
        : OnboardingScreen(onComplete: _completeOnboarding);
  }
}

class VokeyShell extends StatefulWidget {
  const VokeyShell({super.key});
  @override
  State<VokeyShell> createState() => _VokeyShellState();
}

class _VokeyShellState extends State<VokeyShell> {
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    unawaited(AdMobService.instance.initialize());
  }

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const HistoryScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: VokeyApp.surface,
        indicatorColor: VokeyApp.cyan.withValues(alpha: .14),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) =>
            setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_rounded),
            label: 'History',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Settings',
          ),
        ],
      ),
    );
  }
}
