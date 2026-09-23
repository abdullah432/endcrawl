/// A canvas format — the *output* aspect ratio and resolution, which is
/// independent of how the phone is held while editing.
class CanvasFormat {
  final String id;
  final String label;
  final String sub;
  final int w;
  final int h;

  /// The short ratio shown in a frame's corner and on template rows —
  /// "2.39:1", "16:9", "9:16".
  final String aspect;

  const CanvasFormat({
    required this.id,
    required this.label,
    required this.sub,
    required this.w,
    required this.h,
    required this.aspect,
  });

  /// A custom size, labelled by its reduced ratio.
  factory CanvasFormat.custom(int w, int h) =>
      CanvasFormat(id: customId, label: 'Custom', sub: '$w × $h', w: w, h: h, aspect: aspectLabel(w, h));

  static const customId = 'custom';

  bool get isPortrait => h > w;

  /// The formats offered on 2.3, in the design's order.
  static const picker = <CanvasFormat>[
    CanvasFormat(id: '16x9', label: '16:9 HD', sub: '1920 × 1080', w: 1920, h: 1080, aspect: '16:9'),
    CanvasFormat(id: '239', label: '2.39:1 scope', sub: '2048 × 858', w: 2048, h: 858, aspect: '2.39:1'),
    CanvasFormat(id: '185', label: '1.85:1 flat', sub: '1998 × 1080', w: 1998, h: 1080, aspect: '1.85:1'),
    CanvasFormat(id: '9x16', label: '9:16 vertical', sub: '1080 × 1920', w: 1080, h: 1920, aspect: '9:16'),
    CanvasFormat(id: '1x1', label: '1:1 square', sub: '1080 × 1080', w: 1080, h: 1080, aspect: '1:1'),
    CanvasFormat(id: 'uhd', label: '4K UHD', sub: '3840 × 2160', w: 3840, h: 2160, aspect: '16:9'),
  ];

  /// Formats v1 offered that v2 doesn't. Still recognised, so a project
  /// saved in one keeps its exact size instead of silently changing shape.
  static const _legacy = <CanvasFormat>[
    CanvasFormat(id: '4x5', label: '4:5', sub: '1080 × 1350', w: 1080, h: 1350, aspect: '4:5'),
    CanvasFormat(id: 'dcif', label: 'DCI 4K flat', sub: '3996 × 2160', w: 3996, h: 2160, aspect: '1.85:1'),
    CanvasFormat(id: 'dcis', label: 'DCI 4K scope', sub: '4096 × 1716', w: 4096, h: 1716, aspect: '2.39:1'),
  ];

  static const presets = [...picker, ..._legacy];

  static CanvasFormat byId(String id) => presets.firstWhere((f) => f.id == id, orElse: () => picker.first);
}

/// "16:9", "2.39:1" — a ratio the way editors say it: small integers when
/// they reduce cleanly, otherwise width over height to two places.
String aspectLabel(int w, int h) {
  if (w <= 0 || h <= 0) return '—';
  int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
  final g = gcd(w, h);
  final (a, b) = (w ~/ g, h ~/ g);
  if (a <= 32 && b <= 32) return '$a:$b';
  final ratio = w >= h ? w / h : h / w;
  final r = ratio.toStringAsFixed(2);
  return w >= h ? '$r:1' : '1:$r';
}

/// The project frame rates offered on 2.3 — part of the project, not the
/// export dialog, because they decide which scroll speeds run without
/// judder.
const kFrameRates = <double>[24, 23.976, 25, 29.97, 30, 48, 60];
