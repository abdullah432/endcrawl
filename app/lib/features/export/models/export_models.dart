enum Codec { h264, hevc, prores, png }

extension CodecX on Codec {
  String get label => switch (this) {
        Codec.h264 => 'H.264',
        Codec.hevc => 'HEVC',
        Codec.prores => 'ProRes 4444',
        Codec.png => 'PNG sequence',
      };
  String get description => switch (this) {
        Codec.h264 => 'Universal. No alpha.',
        Codec.hevc => 'Smaller, newer devices.',
        Codec.prores => 'Drops straight onto a timeline with transparency.',
        Codec.png => 'Frame-accurate stills with alpha.',
      };
  bool get hasAlpha => this == Codec.prores || this == Codec.png;

  /// Simulated Mbps used only to estimate a file size for the UI — there is
  /// no real encoder behind this prototype-fidelity build.
  double get simulatedMbps => switch (this) {
        Codec.h264 => 12,
        Codec.hevc => 9,
        Codec.prores => 220,
        Codec.png => 340,
      };
}

enum ExportResolution { source, hd, sd }

extension ExportResolutionX on ExportResolution {
  String label(int sourceWidth) => switch (this) {
        ExportResolution.source => 'Source ${sourceWidth}p',
        ExportResolution.hd => '1920 HD',
        ExportResolution.sd => '1280',
      };

  double scaleFactor(int sourceWidth) => switch (this) {
        ExportResolution.source => 1,
        ExportResolution.hd => (1920 / sourceWidth).clamp(0, 1),
        ExportResolution.sd => (1280 / sourceWidth).clamp(0, 1),
      };
}

enum ExportPhase { idle, running, failed, done }

class ExportRun {
  final double pct;
  final ExportPhase phase;
  const ExportRun({required this.pct, required this.phase});
}
