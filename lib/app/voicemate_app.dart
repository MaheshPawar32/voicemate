import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../features/home/home_screen.dart';
import '../features/onboarding/onboarding_screen.dart';
import '../features/settings/settings_screen.dart';

class VoiceMateApp extends StatelessWidget {
  const VoiceMateApp({super.key});

  static const background = Color(0xFF0B1020);
  static const surface = Color(0xFF131B2E);
  static const card = Color(0xFF19243A);
  static const cyan = Color(0xFF26D9E8);
  static const violet = Color(0xFF7777FF);
  static const muted = Color(0xFF9BA9BE);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'VoiceMate',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        scaffoldBackgroundColor: background,
        colorScheme: const ColorScheme.dark(
          primary: cyan,
          secondary: violet,
          surface: surface,
          error: Color(0xFFFF657A),
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: background,
          foregroundColor: Color(0xFFF4F7FF),
          elevation: 0,
          centerTitle: false,
        ),
        cardTheme: CardThemeData(
          color: card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: surface,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide.none,
          ),
        ),
      ),
      home: const _AppEntry(),
    );
  }
}

class _AppEntry extends StatefulWidget {
  const _AppEntry();

  @override
  State<_AppEntry> createState() => _AppEntryState();
}

class _AppEntryState extends State<_AppEntry> {
  late final Box<dynamic> _settings;

  @override
  void initState() {
    super.initState();
    _settings = Hive.box<dynamic>('voicemate_settings');
  }

  Future<void> _completeOnboarding() async {
    await _settings.put('onboarding_complete', true);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final complete = _settings.get('onboarding_complete', defaultValue: false) == true;
    return complete
        ? const VoiceMateShell()
        : OnboardingScreen(onComplete: _completeOnboarding);
  }
}

class VoiceMateShell extends StatefulWidget {
  const VoiceMateShell({super.key});

  @override
  State<VoiceMateShell> createState() => _VoiceMateShellState();
}

class _VoiceMateShellState extends State<VoiceMateShell> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = <Widget>[
      const HomeScreen(),
      const _DiscoverScreen(),
      const _HistoryScreen(),
      const SettingsScreen(),
    ];
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: pages),
      bottomNavigationBar: NavigationBar(
        backgroundColor: VoiceMateApp.surface,
        indicatorColor: VoiceMateApp.cyan.withValues(alpha: .14),
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) => setState(() => _selectedIndex = index),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.grid_view_rounded), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'Settings'),
        ],
      ),
    );
  }
}

class _DiscoverScreen extends StatelessWidget {
  const _DiscoverScreen();

  @override
  Widget build(BuildContext context) => const _SimplePage(
    title: 'Discover',
    subtitle: 'Explore the tools available in VoiceMate.',
    icon: Icons.explore_outlined,
    message: 'The clap test is available as a foreground diagnostic. Whistle detection and background monitoring are planned for later.'
  );
}

class _HistoryScreen extends StatelessWidget {
  const _HistoryScreen();

  @override
  Widget build(BuildContext context) => const _SimplePage(
    title: 'History',
    subtitle: 'Your recent finder activity.',
    icon: Icons.history_rounded,
    message: 'No activity yet. Detection events will appear here after the finder engine is implemented.',
  );
}

class _SimplePage extends StatelessWidget {
  const _SimplePage({required this.title, required this.subtitle, required this.icon, required this.message});

  final String title;
  final String subtitle;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(22),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const SizedBox(height: 18),
        Text(title, style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        Text(subtitle, style: const TextStyle(color: VoiceMateApp.muted)),
        const Spacer(),
        Center(child: Icon(icon, size: 58, color: VoiceMateApp.cyan)),
        const SizedBox(height: 18),
        Text(message, textAlign: TextAlign.center, style: const TextStyle(color: VoiceMateApp.muted, height: 1.5)),
        const Spacer(),
      ]),
    ),
  );
}
