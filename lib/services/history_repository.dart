import 'package:hive/hive.dart';

/// Persists event metadata only; never accepts or stores microphone audio.
class HistoryRepository {
  HistoryRepository(this._box);

  static const storageKey = 'history_events';
  static const maxEvents = 250;
  final Box<dynamic> _box;

  Future<void> record({
    required String eventType,
    Map<String, Object?> metadata = const {},
  }) async {
    final raw = _box.get(storageKey, defaultValue: <dynamic>[]);
    final events = raw is List
        ? raw.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList()
        : <Map<String, dynamic>>[];
    final now = DateTime.now();
    events.add({
      'id': now.microsecondsSinceEpoch.toString(),
      'event_type': eventType,
      'timestamp': now.millisecondsSinceEpoch,
      'metadata': Map<String, Object?>.from(metadata),
    });
    if (events.length > maxEvents) {
      events.removeRange(0, events.length - maxEvents);
    }
    await _box.put(storageKey, events);
  }

  List<Map<String, dynamic>> readAll() {
    final raw = _box.get(storageKey, defaultValue: <dynamic>[]);
    if (raw is! List) return <Map<String, dynamic>>[];
    final events = <Map<String, dynamic>>[];
    for (final item in raw.whereType<Map>()) {
      final event = Map<String, dynamic>.from(item);
      if (event['event_type'] is! String || event['timestamp'] is! int) {
        continue;
      }
      final metadata = event['metadata'];
      event['metadata'] = metadata is Map
          ? Map<String, dynamic>.from(metadata)
          : <String, dynamic>{};
      events.add(event);
    }
    events.sort(
        (a, b) => (b['timestamp'] as int).compareTo(a['timestamp'] as int));
    return events;
  }

  Future<void> clear() => _box.delete(storageKey);
}
