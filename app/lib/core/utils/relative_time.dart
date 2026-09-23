/// Short relative timestamp for library cards ("2 min ago", "1 hour ago").
///
/// Deliberately coarse: the library only needs to convey recency, and a
/// coarse label avoids a per-second rebuild to stay accurate.
String formatRelativeTime(DateTime time, {DateTime? now}) {
  final elapsed = (now ?? DateTime.now()).toUtc().difference(time.toUtc());

  String unit(int n, String one) => '$n ${n == 1 ? one : '${one}s'} ago';

  if (elapsed.isNegative || elapsed.inSeconds < 60) return 'a moment ago';
  if (elapsed.inMinutes < 60) return '${elapsed.inMinutes} min ago';
  if (elapsed.inHours < 24) return unit(elapsed.inHours, 'hour');
  if (elapsed.inDays == 1) return 'yesterday';
  if (elapsed.inDays < 7) return unit(elapsed.inDays, 'day');
  if (elapsed.inDays < 30) return unit((elapsed.inDays / 7).floor(), 'week');
  if (elapsed.inDays < 365) return unit((elapsed.inDays / 30).floor(), 'month');
  return unit((elapsed.inDays / 365).floor(), 'year');
}
