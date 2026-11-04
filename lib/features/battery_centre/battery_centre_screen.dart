import 'package:flutter/material.dart';

import '../../app/voicemate_app.dart';
import '../../services/device_info_service.dart';

class BatteryCentreScreen extends StatefulWidget {
  const BatteryCentreScreen({super.key});

  @override
  State<BatteryCentreScreen> createState() => _BatteryCentreScreenState();
}

class _BatteryCentreScreenState extends State<BatteryCentreScreen> {
  final DeviceInfoService _service = DeviceInfoService();
  late Future<BatterySnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    _snapshot = _service.getBatterySnapshot();
  }

  void _refresh() {
    setState(() => _snapshot = _service.getBatterySnapshot());
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Battery & performance'),
      actions: [
        IconButton(
          tooltip: 'Refresh battery information',
          onPressed: _refresh,
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
    ),
    body: FutureBuilder<BatterySnapshot>(
      future: _snapshot,
      builder: (context, state) {
        if (state.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (state.hasError || !state.hasData) {
          return _ErrorState(
            message: state.error?.toString() ?? 'Battery information is unavailable.',
            onRetry: _refresh,
          );
        }
        final snapshot = state.data!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Container(
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF18365A), Color(0xFF111D32)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: VoiceMateApp.cyan.withValues(alpha: .24)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('CURRENT BATTERY',
                    style: TextStyle(
                      color: VoiceMateApp.muted,
                      fontSize: 11,
                      letterSpacing: 1.4,
                      fontWeight: FontWeight.w800)),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        snapshot.levelPercent >= 0
                          ? '${snapshot.levelPercent}%'
                          : 'N/A',
                        style: const TextStyle(
                          fontSize: 42, fontWeight: FontWeight.w800)),
                      const Spacer(),
                      Icon(
                        snapshot.status == 'charging'
                          ? Icons.battery_charging_full_rounded
                          : Icons.battery_full_rounded,
                        size: 48, color: VoiceMateApp.cyan),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: snapshot.levelPercent >= 0
                        ? snapshot.levelPercent / 100 : null,
                      minHeight: 9,
                      backgroundColor: VoiceMateApp.surface,
                      color: snapshot.levelPercent <= 15
                        ? const Color(0xFFFF657A)
                        : VoiceMateApp.cyan,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(_statusLabel(snapshot),
                    style: const TextStyle(color: VoiceMateApp.muted)),
                ],
              ),
            ),
            const SizedBox(height: 22),
            const Text('Device readings', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _ReadingTile(
              icon: Icons.health_and_safety_outlined,
              title: 'Battery health',
              value: _humanize(snapshot.health)),
            _ReadingTile(
              icon: Icons.device_thermostat_rounded,
              title: 'Battery temperature',
              value: snapshot.temperatureC >= 0
                ? '${snapshot.temperatureC.toStringAsFixed(1)} °C'
                : 'Unavailable'),
            _ReadingTile(
              icon: Icons.electrical_services_rounded,
              title: 'Battery voltage',
              value: snapshot.voltageMv > 0
                ? '${snapshot.voltageMv} mV'
                : 'Unavailable'),
            _ReadingTile(
              icon: Icons.power_rounded,
              title: 'Power source',
              value: _humanize(snapshot.pluggedSource)),
            const SizedBox(height: 22),
            const Text('Memory & performance', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _ReadingTile(
              icon: Icons.memory_rounded,
              title: 'Total RAM',
              value: snapshot.totalRamMb > 0
                ? '${snapshot.totalRamMb} MB'
                : 'Unavailable'),
            _ReadingTile(
              icon: Icons.memory_rounded,
              title: 'Available RAM',
              value: snapshot.availableRamMb >= 0
                ? '${snapshot.availableRamMb} MB'
                : 'Unavailable',
              valueColor: snapshot.lowMemory
                ? const Color(0xFFFFBE55)
                : null),
            _ReadingTile(
              icon: Icons.phone_android_rounded,
              title: 'VoiceMate memory',
              value: snapshot.appMemoryPssMb >= 0
                ? '${snapshot.appMemoryPssMb} MB'
                : 'Unavailable'),
            const SizedBox(height: 22),
            const Text('Power management', style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 12),
            _ReadingTile(
              icon: Icons.energy_savings_leaf_outlined,
              title: 'Battery saver',
              value: snapshot.powerSaveMode ? 'On' : 'Off',
              valueColor: snapshot.powerSaveMode
                ? const Color(0xFFFFBE55) : const Color(0xFF38D99A)),
            _ReadingTile(
              icon: Icons.battery_saver_outlined,
              title: 'Battery optimization',
              value: snapshot.batteryOptimizationIgnored
                ? 'Not optimized'
                : 'Optimized by Android',
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                color: VoiceMateApp.surface,
                borderRadius: BorderRadius.circular(16)),
              child: const Text(
                'These are system snapshots, not a CPU benchmark or guaranteed battery-life estimate. Android may limit background work to protect battery life. VoiceMate does not request battery-optimization exemptions automatically. Check your phone manufacturer’s battery settings if monitoring is stopped by the system.',
                style: TextStyle(
                  color: VoiceMateApp.muted, height: 1.5, fontSize: 12)),
            ),
          ],
        );
      },
    ),
  );

  String _statusLabel(BatterySnapshot snapshot) {
    switch (snapshot.status) {
      case 'charging':
        return 'Charging · ${_humanize(snapshot.pluggedSource)}';
      case 'full':
        return 'Fully charged';
      case 'discharging':
        return 'On battery';
      case 'not_charging':
        return 'Connected but not charging';
      default:
        return 'Battery status unavailable';
    }
  }

  String _humanize(String value) => value
      .replaceAll('_', ' ')
      .split(' ')
      .map((part) => part.isEmpty
          ? part
          : '${part[0].toUpperCase()}${part.substring(1)}')
      .join(' ');
}

class _ReadingTile extends StatelessWidget {
  const _ReadingTile({
    required this.icon,
    required this.title,
    required this.value,
    this.valueColor,
  });

  final IconData icon;
  final String title;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      leading: Icon(icon, color: VoiceMateApp.cyan),
      title: Text(title),
      trailing: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 145),
        child: Text(value, textAlign: TextAlign.end,
          style: TextStyle(
            color: valueColor ?? VoiceMateApp.muted,
            fontWeight: FontWeight.w700)),
      ),
    ),
  );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.battery_unknown_rounded,
            size: 48, color: VoiceMateApp.cyan),
          const SizedBox(height: 14),
          const Text('Could not read battery information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Text(message, textAlign: TextAlign.center,
            style: const TextStyle(color: VoiceMateApp.muted)),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Try again')),
        ],
      ),
    ),
  );
}
