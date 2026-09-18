/// Short relative timestamp for library rows ("2 min ago").
///
/// Deliberately coarse: the library only needs to convey recency, and a
/// coarse label avoids a per-second rebuild to stay accurate.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).toUtc().difference(time.toUtc());

  if (elapsed.isNegative || elapsed.inSeconds < 60) return 'just now';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return '${elapsed.inHours} hr ago';
  if (elapsed.inDays == 1) return 'yesterday';
  if (elapsed.inDays < 7) return '${elapsed.inDays} days ago';
  if (elapsed.inDays < 30) return '${(elapsed.inDays / 7).floor()} wk ago';
  if (elapsed.inDays < 365) return '${(elapsed.inDays / 30).floor()} mo ago';
  return '${(elapsed.inDays / 365).floor()} yr ago';
}
