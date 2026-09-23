/// Display formatting shared across screens, so "24 fps" and "01:42" read
/// the same everywhere.
library;

/// "24 fps", "23.976 fps", "29.97 fps".
String formatFps(double fps) {
  final whole = fps == fps.roundToDouble();
  return '${whole ? fps.toStringAsFixed(0) : _trimZeros(fps.toStringAsFixed(3))} fps';
}

/// "01:42" — minutes and seconds, as runtimes appear on cards and chips.
String formatRuntime(Duration d) {
  final s = d.inSeconds;
  return '${(s ~/ 60).toString().padLeft(2, '0')}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "1 name", "3 names".
String plural(int n, String one, [String? many]) => '$n ${n == 1 ? one : (many ?? '${one}s')}';

String _trimZeros(String s) => s.contains('.') ? s.replaceFirst(RegExp(r'0+$'), '').replaceFirst(RegExp(r'\.$'), '') : s;

/// "0:06", "2:41" — a block's share of the roll, on its row.
String formatClock(double seconds) {
  final s = seconds.round();
  return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
}

/// "4", "6.41" — pixels per frame, whole when it is whole.
String formatPpf(double ppf) =>
    (ppf - ppf.roundToDouble()).abs() < 0.0008 ? ppf.round().toString() : ppf.toStringAsFixed(2);
