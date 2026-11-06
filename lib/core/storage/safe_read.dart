/// Type-tolerant readers for Hive values. Stored data can be wrongly typed
/// after a bad migration or manual tampering; reads must never throw.
int readInt(Object? value, int fallback) =>
    value is num ? value.toInt() : fallback;
