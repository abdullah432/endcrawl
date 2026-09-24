import 'dart:math';

/// The codecs on 6.1. Every one is on the free plan; 6.1 lists the ones
/// this device can make.
enum Codec {
  h264('H.264', 'Universal review copy', 12, 'mp4'),
  hevc('HEVC', 'Smaller file, same picture', 9, 'mp4'),
  prores422('ProRes 422 HQ', 'Edit-friendly master', 154, 'mov'),
  prores4444('ProRes 4444', 'Transparent background', 220, 'mov', alpha: true),
  png('PNG sequence', 'One image per frame', 139, 'zip', alpha: true);

  final String label;
  final String description;

  /// Bit rate at 1920 × 1080, in megabits per second. H.264 and HEVC are
  /// encoded at this rate (scaled by pixel count), so their estimate is
  /// close; ProRes and PNG depend on the picture, so theirs is typical.
  final double mbpsAtHd;
  final String extension;
  final bool alpha;

  const Codec(this.label, this.description, this.mbpsAtHd, this.extension, {this.alpha = false});

  /// Whether the encoder is told this rate (rather than it being typical).
  bool get hasTargetRate => this == h264 || this == hevc;

  /// Encoders that can hold alpha, in order of preference.
  static const alphaCodecs = [prores4444, png];
}

/// Output size by its long edge; the other follows the canvas's shape, so
/// "1920 HD" is 1920 × 1080 for 16:9 and 1080 × 1920 for 9:16.
enum ExportResolution {
  small('1280', 1280),
  hd('1920 HD', 1920),
  uhd('4K UHD', 3840);

  final String label;
  final int edge;
  const ExportResolution(this.label, this.edge);

  /// The option nearest a canvas's own long edge, among [options].
  static ExportResolution nearest(int canvasW, int canvasH, [Iterable<ExportResolution> options = values]) {
    final long = max(canvasW, canvasH);
    return options.reduce((a, b) => (a.edge - long).abs() <= (b.edge - long).abs() ? a : b);
  }

  /// Output pixels for a canvas, kept even as encoders require.
  (int, int) sizeFor(int canvasW, int canvasH) {
    int even(double v) => max(2, (v / 2).round() * 2);
    return canvasW >= canvasH ? (edge, even(canvasH * edge / canvasW)) : (even(canvasW * edge / canvasH), edge);
  }
}

double _pixelRatio(int w, int h) => (w * h) / (1920 * 1080);

/// The bit rate an encode targets, in bits per second.
int bitsPerSecond(Codec codec, int w, int h) => (codec.mbpsAtHd * _pixelRatio(w, h) * 1e6).round();

/// Estimated file size in bytes.
double estimateBytes(Codec codec, int w, int h, double seconds) => bitsPerSecond(codec, w, h) * seconds / 8;

/// Estimated wall-clock render time, in seconds — a first guess until the
/// render measures its own pace.
double estimateRenderSeconds(int w, int h, double seconds) => seconds * _pixelRatio(w, h) * 1.1;

/// The frame rate as a fraction: whole rates over 1, NTSC rates (23.976,
/// 29.97, 59.94) exactly over 1001.
(int, int) frameRateFraction(double fps) {
  final whole = fps.round();
  if ((fps - whole).abs() < 0.001) return (whole, 1);
  final ntsc = (fps * 1.001).round();
  if ((ntsc * 1000 / 1001 - fps).abs() < 0.01) return (ntsc * 1000, 1001);
  return ((fps * 1000).round(), 1000);
}

/// "242 MB", "3.1 GB", "640 KB".
String formatBytes(double bytes) {
  if (bytes >= 1e9) return '${(bytes / 1e9).toStringAsFixed(1)} GB';
  if (bytes < 1e6) return '${max(1, (bytes / 1e3).round())} KB';
  return '${(bytes / 1e6).round()} MB';
}

/// A render's filename: the title, kept to what every filesystem accepts.
String exportFileName(String title, Codec codec) {
  final stem = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\x00-\x1F]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  return '${stem.isEmpty ? 'EndCrawl render' : stem}.${codec.extension}';
}

/// "about 3 min", "about 1m 52s", "about 40s".
String formatAbout(double seconds) {
  final s = seconds.round();
  if (s < 60) return 'about ${max(1, s)}s';
  if (s >= 150) return 'about ${(s / 60).round()} min';
  return 'about ${s ~/ 60}m ${(s % 60).toString().padLeft(2, '0')}s';
}

enum ExportPhase { running, failed, done }

/// Why an encode stopped.
enum EncoderFailureKind { outOfSpace, unsupported, failed }

/// One render: what it is of, how far it has got, and how it ended.
class ExportRun {
  final String projectId;
  final String projectTitle;
  final Codec codec;
  final int width;
  final int height;
  final double fps;

  /// Frames in the render — the engine's estimate, then the renderer's own
  /// count once it has laid the roll out.
  final int totalFrames;

  /// Frames written so far.
  final int frame;
  final ExportPhase phase;

  /// Seconds left, measured from the pace so far; null until there's a
  /// pace to measure.
  final double? measuredSecondsLeft;

  /// Why it stopped (6.3).
  final EncoderFailureKind? failure;
  final String? failureMessage;

  /// Space the file needs, when it stopped for lack of it.
  final double? neededBytes;

  /// The finished file and its real size (6.4).
  final String? outputPath;
  final int? fileBytes;

  const ExportRun({
    required this.projectId,
    required this.projectTitle,
    required this.codec,
    required this.width,
    required this.height,
    required this.fps,
    required this.totalFrames,
    this.frame = 0,
    this.phase = ExportPhase.running,
    this.measuredSecondsLeft,
    this.failure,
    this.failureMessage,
    this.neededBytes,
    this.outputPath,
    this.fileBytes,
  });

  double get progress => totalFrames == 0 ? 0 : (frame / totalFrames).clamp(0.0, 1.0);
  double get seconds => totalFrames / fps;

  /// The estimate before the file exists.
  double get bytes => estimateBytes(codec, width, height, seconds);

  double get secondsLeft => measuredSecondsLeft ?? estimateRenderSeconds(width, height, seconds) * (1 - progress);

  ExportRun copyWith({
    int? frame,
    int? totalFrames,
    ExportPhase? phase,
    double? measuredSecondsLeft,
    EncoderFailureKind? failure,
    String? failureMessage,
    double? neededBytes,
    String? outputPath,
    int? fileBytes,
  }) =>
      ExportRun(
        projectId: projectId,
        projectTitle: projectTitle,
        codec: codec,
        width: width,
        height: height,
        fps: fps,
        totalFrames: totalFrames ?? this.totalFrames,
        frame: frame ?? this.frame,
        phase: phase ?? this.phase,
        measuredSecondsLeft: measuredSecondsLeft ?? this.measuredSecondsLeft,
        failure: failure ?? this.failure,
        failureMessage: failureMessage ?? this.failureMessage,
        neededBytes: neededBytes ?? this.neededBytes,
        outputPath: outputPath ?? this.outputPath,
        fileBytes: fileBytes ?? this.fileBytes,
      );
}
