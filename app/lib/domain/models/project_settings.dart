import 'credit_face.dart';
import 'json_support.dart';

enum TimingMode { duration, speed }

enum RollLook { flat2d, crawl3d }

enum MonitorBackground { black, alpha, green, custom, underlay }

/// Everything about the project that isn't the block document itself:
/// format, frame rate, timing lock, look, background, and safe guides.
class ProjectSettings {
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
  final CreditFace? face; // null = the app default (grotesque)
  final bool safeGuides;

  const ProjectSettings({
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

  Map<String, Object?> toJson() => {
        'formatId': formatId,
        'customW': customW,
        'customH': customH,
        'fps': fps,
        'mode': mode.name,
        'durationFrames': durationFrames,
        'ppf': ppf,
        'headSeconds': headSeconds,
        'tailSeconds': tailSeconds,
        'look': look.name,
        'tilt': tilt,
        'vanishingDistance': vanishingDistance,
        'background': background.name,
        'face': face?.name,
        'safeGuides': safeGuides,
      };

  factory ProjectSettings.fromJson(Map<String, Object?> json) {
    const defaults = ProjectSettings();
    return ProjectSettings(
      formatId: asString(json['formatId'], defaults.formatId),
      customW: asInt(json['customW'], defaults.customW),
      customH: asInt(json['customH'], defaults.customH),
      fps: asDouble(json['fps'], defaults.fps),
      mode: asEnum(TimingMode.values, json['mode'], defaults.mode),
      durationFrames: asInt(json['durationFrames'], defaults.durationFrames),
      ppf: asDouble(json['ppf'], defaults.ppf),
      headSeconds: asDouble(json['headSeconds'], defaults.headSeconds),
      tailSeconds: asDouble(json['tailSeconds'], defaults.tailSeconds),
      look: asEnum(RollLook.values, json['look'], defaults.look),
      tilt: asDouble(json['tilt'], defaults.tilt),
      vanishingDistance: asDouble(json['vanishingDistance'], defaults.vanishingDistance),
      background: asEnum(MonitorBackground.values, json['background'], defaults.background),
      face: json['face'] == null ? null : asEnum(CreditFace.values, json['face'], CreditFace.grotesque),
      safeGuides: asBool(json['safeGuides'], defaults.safeGuides),
    );
  }
}
