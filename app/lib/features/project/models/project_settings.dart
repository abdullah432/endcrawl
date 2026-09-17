import '../../../core/theme/app_theme.dart' show CreditFace;

enum TimingMode { duration, speed }

enum RollLook { flat2d, crawl3d }

enum MonitorBackground { black, alpha, green, custom, underlay }

/// Everything about the project that isn't the block document itself:
/// format, frame rate, timing lock, look, background, and safe guides.
/// Ported from the prototype's `state.project`.
class ProjectSettings {
  final String name;
  final String formatId; // 'custom' or a CanvasFormat id
  final int customW;
  final int customH;
  final double fps;
  final TimingMode mode;
  final int durationFrames;
  final double ppf; // pixels per frame, used when mode == speed
  final double headSeconds;
  final double tailSeconds;
  final RollLook look;
  final double tilt; // degrees, 3D mode
  final double vanishingDistance; // percent, 3D mode
  final MonitorBackground background;
  final CreditFace? face; // null = use the app default (grotesque)
  final bool safeGuides;

  const ProjectSettings({
    this.name = 'UNTITLED',
    this.formatId = '239',
    this.customW = 1080,
    this.customH = 1920,
    this.fps = 24,
    this.mode = TimingMode.duration,
    this.durationFrames = 24 * 104,
    this.ppf = 3,
    this.headSeconds = 2,
    this.tailSeconds = 3,
    this.look = RollLook.flat2d,
    this.tilt = 22,
    this.vanishingDistance = 60,
    this.background = MonitorBackground.black,
    this.face,
    this.safeGuides = true,
  });

  ProjectSettings copyWith({
    String? name,
    String? formatId,
    int? customW,
    int? customH,
    double? fps,
    TimingMode? mode,
    int? durationFrames,
    double? ppf,
    double? headSeconds,
    double? tailSeconds,
    RollLook? look,
    double? tilt,
    double? vanishingDistance,
    MonitorBackground? background,
    CreditFace? face,
    bool? safeGuides,
  }) {
    return ProjectSettings(
      name: name ?? this.name,
      formatId: formatId ?? this.formatId,
      customW: customW ?? this.customW,
      customH: customH ?? this.customH,
      fps: fps ?? this.fps,
      mode: mode ?? this.mode,
      durationFrames: durationFrames ?? this.durationFrames,
      ppf: ppf ?? this.ppf,
      headSeconds: headSeconds ?? this.headSeconds,
      tailSeconds: tailSeconds ?? this.tailSeconds,
      look: look ?? this.look,
      tilt: tilt ?? this.tilt,
      vanishingDistance: vanishingDistance ?? this.vanishingDistance,
      background: background ?? this.background,
      face: face ?? this.face,
      safeGuides: safeGuides ?? this.safeGuides,
    );
  }
}
