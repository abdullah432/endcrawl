/// A canvas format preset — the *output* aspect ratio/resolution, which is
/// independent of how the editor UI is laid out on the device. Ported from
/// the prototype's `FMT` table.
class CanvasFormat {
  final String id;
  final String label;
  final String sub;
  final int w;
  final int h;

  const CanvasFormat({
    required this.id,
    required this.label,
    required this.sub,
    required this.w,
    required this.h,
  });

  static const presets = <CanvasFormat>[
    CanvasFormat(id: '9x16', label: '9:16 Vertical', sub: '1080×1920', w: 1080, h: 1920),
    CanvasFormat(id: '4x5', label: '4:5', sub: '1080×1350', w: 1080, h: 1350),
    CanvasFormat(id: '1x1', label: '1:1 Square', sub: '1080×1080', w: 1080, h: 1080),
    CanvasFormat(id: '16x9', label: '16:9 HD', sub: '1920×1080', w: 1920, h: 1080),
    CanvasFormat(id: 'uhd', label: '16:9 UHD', sub: '3840×2160', w: 3840, h: 2160),
    CanvasFormat(id: '185', label: '1.85:1 Flat', sub: '1998×1080', w: 1998, h: 1080),
    CanvasFormat(id: '239', label: '2.39:1 Scope', sub: '2048×858', w: 2048, h: 858),
    CanvasFormat(id: 'dcif', label: 'DCI 4K Flat', sub: '3996×2160', w: 3996, h: 2160),
    CanvasFormat(id: 'dcis', label: 'DCI 4K Scope', sub: '4096×1716', w: 4096, h: 1716),
  ];

  static CanvasFormat byId(String id) =>
      presets.firstWhere((f) => f.id == id, orElse: () => presets[6]);
}

/// The supported project frame rates — part of the project, not the export
/// dialog (§3 of the brief).
const kFrameRates = <double>[23.976, 24, 25, 29.97, 30, 50, 60];
