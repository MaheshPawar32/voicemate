import 'package:flutter/services.dart';
import 'package:hive/hive.dart';

import '../core/storage/safe_read.dart';

/// Metadata for a user-imported alert sound. The audio itself lives only in
/// Android app-private storage (`filesDir/custom_sounds/<file_name>`).
class CustomSound {
  const CustomSound({
    required this.id,
    required this.name,
    required this.fileName,
    required this.durationMs,
    required this.sizeBytes,
    required this.importedAt,
  });

  static const idPrefix = 'custom:';

  /// `custom:<file_name>`
  final String id;
  final String name;
  final String fileName;
  final int durationMs;
  final int sizeBytes;
  final int importedAt;

  static bool isCustomId(String id) => id.startsWith(idPrefix);

  Map<String, Object> toMap() => {
        'id': id,
        'name': name,
        'file_name': fileName,
        'duration_ms': durationMs,
        'size_bytes': sizeBytes,
        'imported_at': importedAt,
      };

  static CustomSound? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final fileName = raw['file_name'];
    final name = raw['name'];
    if (fileName is! String || name is! String || fileName.isEmpty) return null;
    return CustomSound(
      id: '$idPrefix$fileName',
      name: name,
      fileName: fileName,
      durationMs: readInt(raw['duration_ms'], 0),
      sizeBytes: readInt(raw['size_bytes'], 0),
      importedAt: readInt(raw['imported_at'], 0),
    );
  }

  CustomSound renamed(String newName) => CustomSound(
        id: id,
        name: newName,
        fileName: fileName,
        durationMs: durationMs,
        sizeBytes: sizeBytes,
        importedAt: importedAt,
      );
}

class CustomSoundException implements Exception {
  const CustomSoundException(this.message);
  final String message;
  @override
  String toString() => message;
}

class CustomSoundsRepository {
  CustomSoundsRepository(this._box, {MethodChannel? channel})
      : _channel =
            channel ?? const MethodChannel('com.dev.vokey/monitoring/methods');

  static const storageKey = 'custom_sounds';
  static const maxSounds = 20;

  final Box<dynamic> _box;
  final MethodChannel _channel;

  List<CustomSound> readAll() {
    final raw = _box.get(storageKey);
    if (raw is! List) return const [];
    return raw.map(CustomSound.fromMap).whereType<CustomSound>().toList();
  }

  CustomSound? byId(String id) {
    for (final s in readAll()) {
      if (s.id == id) return s;
    }
    return null;
  }

  Future<void> _write(List<CustomSound> sounds) =>
      _box.put(storageKey, sounds.map((s) => s.toMap()).toList());

  /// Opens Android's file picker. Returns null if the user cancelled.
  Future<CustomSound?> importFromDevice() async {
    if (readAll().length >= maxSounds) {
      throw const CustomSoundException(
        'You can keep up to $maxSounds custom sounds. Delete one to import another.',
      );
    }
    try {
      final result =
          await _channel.invokeMapMethod<String, dynamic>('importCustomSound');
      if (result == null) return null;
      final sound = CustomSound.fromMap({
        ...result,
        'imported_at': DateTime.now().millisecondsSinceEpoch,
      });
      if (sound == null) {
        throw const CustomSoundException('Vokey could not read that sound.');
      }
      await add(sound);
      return sound;
    } on PlatformException catch (e) {
      throw CustomSoundException(
          e.message ?? 'Vokey could not import that sound.');
    } on MissingPluginException {
      throw const CustomSoundException(
          'Sound import is available on Android only.');
    }
  }

  Future<void> add(CustomSound sound) async {
    final sounds = readAll().where((s) => s.id != sound.id).toList()
      ..add(sound);
    await _write(sounds);
  }

  Future<void> rename(String id, String newName) async {
    final name = newName.trim();
    if (name.isEmpty) return;
    final clipped = name.length > 40 ? name.substring(0, 40) : name;
    await _write([
      for (final s in readAll()) s.id == id ? s.renamed(clipped) : s,
    ]);
  }

  /// Removes the private file and its metadata.
  Future<void> delete(String id) async {
    final sound = byId(id);
    if (sound == null) return;
    try {
      await _channel.invokeMethod<bool>(
          'deleteCustomSound', {'file_name': sound.fileName});
    } on PlatformException {
      // Metadata is still removed; an orphaned private file is harmless.
    } on MissingPluginException {
      // Tests / non-Android.
    }
    await _write(readAll().where((s) => s.id != id).toList());
  }
}
