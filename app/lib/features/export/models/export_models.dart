import 'dart:math';

/// The codecs on 6.1. Every one is on the free plan.
enum Codec {
  h264('H.264', 'Universal review copy', 12),
  hevc('HEVC', 'Smaller file, same picture', 9),
  prores422('ProRes 422 HQ', 'Edit-friendly master', 154),
  prores4444('ProRes 4444', 'Transparent background', 220, alpha: true),
  png('PNG sequence', 'One image per frame', 139, alpha: true);

  final String label;
  final String description;

  /// Typical bit rate at 1920 × 1080, in megabits per second — only for the
  /// size estimate; this build has no encoder behind it.
  final double mbpsAtHd;
  final bool alpha;

  const Codec(this.label, this.description, this.mbpsAtHd, {this.alpha = false});
}

/// Output width; the height follows the canvas's aspect ratio.
enum ExportResolution {
  small('1280', 1280),
  hd('1920 HD', 1920),
  uhd('4K UHD', 3840);

  final String label;
  final int width;
  const ExportResolution(this.label, this.width);

  /// The option nearest a canvas's own width.
  static ExportResolution nearest(int canvasWidth) =>
      values.reduce((a, b) => (a.width - canvasWidth).abs() <= (b.width - canvasWidth).abs() ? a : b);

  /// Output pixels for a canvas, kept even as encoders require.
  (int, int) sizeFor(int canvasW, int canvasH) {
    final h = (canvasH * width / canvasW / 2).round() * 2;
    return (width, max(2, h));
  }
}

double _pixelRatio(int w, int h) => (w * h) / (1920 * 1080);

/// Estimated file size in bytes.
double estimateBytes(Codec codec, int w, int h, double seconds) =>
    codec.mbpsAtHd * _pixelRatio(w, h) * seconds * 1e6 / 8;

/// Estimated wall-clock render time, in seconds.
double estimateRenderSeconds(int w, int h, double seconds) => seconds * _pixelRatio(w, h) * 1.1;

/// "242 MB", "3.1 GB".
String formatBytes(double bytes) {
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  return '${max(1, (bytes / 1e6).round())} MB';
}

/// "about 3 min", "about 1m 52s", "about 40s".
String formatAbout(double seconds) {
  final s = seconds.round();
  if (s < 60) return 'about ${max(1, s)}s';
  if (s >= 150) return 'about ${(s / 60).round()} min';
  return 'about ${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
}

enum ExportPhase { running, failed, done }

/// One render: what it is of, and how far it has got.
class ExportRun {
  final String projectId;
  final String projectTitle;
  final Codec codec;
  final int width;
  final int height;
  final double fps;
  final int totalFrames;
  final double progress; // 0–1
  final ExportPhase phase;

  /// Bytes the rest of the file needs — set when the disk ran out.
  final double? neededBytes;

  const ExportRun({
    required this.projectId,
    required this.projectTitle,
    required this.codec,
    required this.width,
    required this.height,
    required this.fps,
    required this.totalFrames,
    this.progress = 0,
    this.phase = ExportPhase.running,
    this.neededBytes,
  });

  int get frame => (totalFrames * progress).round();
  double get seconds => totalFrames / fps;
  double get bytes => estimateBytes(codec, width, height, seconds);
  double get secondsLeft => estimateRenderSeconds(width, height, seconds) * (1 - progress);

  ExportRun copyWith({double? progress, ExportPhase? phase, double? neededBytes, int? width, int? height}) => ExportRun(
        projectId: projectId,
        projectTitle: projectTitle,
        codec: codec,
        width: width ?? this.width,
        height: height ?? this.height,
        fps: fps,
        totalFrames: totalFrames,
        progress: progress ?? this.progress,
        phase: phase ?? this.phase,
        neededBytes: neededBytes,
      );
}
