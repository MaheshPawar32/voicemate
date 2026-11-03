import 'package:flutter/material.dart';

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
        ),
        cardTheme: CardTheme(
          color: card,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),
      home: const VoiceMateHomeScreen(),
    );
  }
}

class VoiceMateHomeScreen extends StatelessWidget {
  const VoiceMateHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.graphic_eq_rounded, color: VoiceMateApp.cyan),
            SizedBox(width: 10),
            Text('VoiceMate', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Settings',
            onPressed: () {},
            icon: const Icon(Icons.settings_outlined),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Good morning',
                    style: TextStyle(fontSize: 23, fontWeight: FontWeight.w700),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF302A20),
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.circle, color: Color(0xFFFFBE55), size: 9),
                      SizedBox(width: 7),
                      Text('Monitoring OFF', style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF142747), Color(0xFF102033)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(26),
                border: Border.all(color: VoiceMateApp.cyan.withOpacity(.22)),
              ),
              child: Column(
                children: [
                  const Icon(Icons.mic_none_rounded, size: 76, color: VoiceMateApp.cyan),
                  const SizedBox(height: 12),
                  const Text(
                    'Your phone finder is ready',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Set up sound detection to help find your phone. '
                    'Monitoring will show a persistent notification when active.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VoiceMateApp.muted, height: 1.45),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Monitoring will be implemented in the native audio phase.')),
                    ),
                    icon: const Icon(Icons.power_settings_new_rounded),
                    label: const Text('Set up monitoring'),
                    style: FilledButton.styleFrom(
                      backgroundColor: VoiceMateApp.cyan,
                      foregroundColor: const Color(0xFF06111D),
                      minimumSize: const Size.fromHeight(50),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 26),
            const Text('Your tools', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 14),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.28,
              children: const [
                _FeatureTile(icon: Icons.back_hand_rounded, title: 'Clap to Find', subtitle: 'Sound detection'),
                _FeatureTile(icon: Icons.graphic_eq_rounded, title: 'Whistle to Find', subtitle: 'Tone detection'),
                _FeatureTile(icon: Icons.mic_rounded, title: 'Voice Commands', subtitle: 'Offline engine'),
                _FeatureTile(icon: Icons.notifications_active_outlined, title: 'Alert Studio', subtitle: 'Sound and flash'),
              ],
            ),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: VoiceMateApp.surface, borderRadius: BorderRadius.circular(18)),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.shield_outlined, color: VoiceMateApp.cyan),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Privacy first\nAudio processing is designed to stay on your device. VoiceMate does not need an account.',
                      style: TextStyle(height: 1.45),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        backgroundColor: VoiceMateApp.surface,
        selectedIndex: 0,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.widgets_outlined), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.history_rounded), label: 'History'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(15),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: VoiceMateApp.cyan, size: 27),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(subtitle, style: const TextStyle(color: VoiceMateApp.muted, fontSize: 12)),
          ],
        ),
      ),
    );
  }
}
