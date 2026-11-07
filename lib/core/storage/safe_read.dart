import 'dart:math';

/// Type-tolerant readers for Hive values. Stored data can be wrongly typed
/// after a bad migration or manual tampering; reads must never throw.
int readInt(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;

/// Perceptual 0..1 meter level from 16-bit PCM RMS: −60 dBFS → 0, 0 dBFS → 1.
double meterLevel(double rms) {
  if (rms <= 0) return 0;
  const fullScale = 32768.0;
  final db = 20 * (log(rms / fullScale) / ln10);
  return ((db + 60) / 60).clamp(0.0, 1.0);
}
