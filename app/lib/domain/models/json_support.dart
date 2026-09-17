/// Typed, defensive readers for decoding stored documents.
///
/// Every field read goes through these so a malformed or partially-written
/// document degrades to a sane default instead of throwing deep inside a
/// model constructor. Two deliberate exceptions, both in `credit_block.dart`:
/// an unknown block or row *type* throws, because silently dropping an
/// unrecognised block would destroy the user's content on the next save.
library;

/// JSON numbers decode as `int` when they have no fractional part, so every
/// double field has to go through `num`.
double asDouble(Object? value, double fallback) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? fallback;
  return fallback;
}

int asInt(Object? value, int fallback) {
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value) ?? fallback;
  return fallback;
}

String asString(Object? value, String fallback) => value is String ? value : fallback;

bool asBool(Object? value, bool fallback) => value is bool ? value : fallback;

List<String> asStringList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item != null) item.toString(),
  ];
}

List<Map<String, Object?>> asMapList(Object? value) {
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is Map) item.cast<String, Object?>(),
  ];
}

Map<String, Object?> asMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

/// Enums travel as their `name`, never their index — reordering an enum must
/// not silently reinterpret stored documents. An unrecognised name falls back
/// rather than throwing, so a document written by a newer build still opens.
T asEnum<T extends Enum>(List<T> values, Object? value, T fallback) {
  if (value is! String) return fallback;
  for (final candidate in values) {
    if (candidate.name == value) return candidate;
  }
  return fallback;
}

/// Timestamps are stored as epoch milliseconds (UTC). Firestore's own
/// `Timestamp` maps onto this cleanly when that repository is added.
DateTime asDateTime(Object? value, DateTime fallback) {
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  if (value is String) return DateTime.tryParse(value)?.toUtc() ?? fallback;
  return fallback;
}

DateTime? asDateTimeOrNull(Object? value) {
  if (value is num) return DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true);
  if (value is String) return DateTime.tryParse(value)?.toUtc();
  return null;
}

int toEpochMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;
