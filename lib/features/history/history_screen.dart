import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../app/vokey_app.dart';
import '../../services/history_repository.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final box = Hive.box<dynamic>('vokey_settings');
    final repository = HistoryRepository(box);
    return SafeArea(
      child: ValueListenableBuilder<Box<dynamic>>(
        valueListenable: box.listenable(keys: [HistoryRepository.storageKey]),
        builder: (context, _, __) {
          final events = repository.readAll();
          return CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
                sliver: SliverToBoxAdapter(
                  child: Row(children: [
                    const Expanded(
                        child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('History',
                            style: TextStyle(
                                fontSize: 28, fontWeight: FontWeight.w800)),
                        SizedBox(height: 6),
                        Text('Detection events stored on this phone.',
                            style: TextStyle(color: VokeyApp.muted)),
                      ],
                    )),
                    if (events.isNotEmpty)
                      IconButton(
                        tooltip: 'Clear history',
                        onPressed: () => _confirmClear(context, repository),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ]),
                ),
              ),
              if (events.isEmpty)
                const SliverFillRemaining(
                    hasScrollBody: false, child: _EmptyHistory())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 28),
                  sliver: SliverList.separated(
                    itemCount: events.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) =>
                        _HistoryTile(event: events[index]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmClear(
    BuildContext context,
    HistoryRepository repository,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Clear detection history?'),
        content: const Text(
            'This permanently removes event history stored by Vokey on this phone.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Clear history')),
        ],
      ),
    );
    if (confirmed == true) await repository.clear();
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history_rounded,
                size: 58, color: VokeyApp.cyan.withValues(alpha: .75)),
            const SizedBox(height: 16),
            const Text('No detection events yet',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text(
                'Clap and whistle detections made by the finder and foreground test appear here. '
                'Vokey stores event details only, never microphone recordings.',
                textAlign: TextAlign.center,
                style: TextStyle(color: VokeyApp.muted, height: 1.5)),
          ],
        ),
      );
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.event});
  final Map<String, dynamic> event;

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(event['timestamp'] as int)
        .toLocal();
    final metadata = event['metadata'] as Map<String, dynamic>;
    final count = metadata['clap_count'];
    final eventType = event['event_type'] as String;
    final isWhistle = eventType.contains('whistle');
    final isVoice = eventType.startsWith('voice_');
    final quietHours = metadata['quiet_hours'] == true;
    final dateText = '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/${date.year} · '
        '${date.hour.toString().padLeft(2, '0')}:'
        '${date.minute.toString().padLeft(2, '0')}';
    return Card(
        child: ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
      leading: CircleAvatar(
          backgroundColor: const Color(0x2226D9E8),
          child: Icon(
              isVoice
                  ? Icons.record_voice_over_rounded
                  : (isWhistle
                      ? Icons.graphic_eq_rounded
                      : Icons.back_hand_rounded),
              color: VokeyApp.cyan)),
      title: Text(
          eventType == 'voice_find_phone'
              ? 'Voice command · Find phone'
              : (eventType == 'voice_lock_phone'
                  ? 'Voice command · Lock phone'
                  : (isWhistle
                      ? 'Whistle-like tone detected'
                      : (eventType == 'clap_monitor_detected'
                          ? 'Phone finder triggered by clap'
                          : 'Clap detected in test'))),
          style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
          '${isVoice ? dateText : (isWhistle ? '${metadata['whistle_frequency_hz'] ?? 0} Hz · $dateText' : (count is int ? 'Detected clap #$count · $dateText' : dateText))}'
          '${quietHours ? ' · Alerts muted (quiet hours)' : ''}',
          style: const TextStyle(color: VokeyApp.muted)),
    ));
  }
}
