import 'json_support.dart';

enum RenderOutcome { rendered, failed }

/// The outcome of a project's most recent render — what the library's
/// "● Rendered" / "Render failed" status reads from.
///
/// Only finished outcomes are stored. A render in progress is state of the
/// device doing the encoding, not of the document, so "Rendering 40%" is
/// read live from the export controller and never synced.
class RenderSummary {
  final RenderOutcome outcome;
  final String codec;
  final int width;
  final int height;
  final DateTime at;

  const RenderSummary({
    required this.outcome,
    required this.codec,
    required this.width,
    required this.height,
    required this.at,
  });

  Map<String, Object?> toJson() => {
        'outcome': outcome.name,
        'codec': codec,
        'width': width,
        'height': height,
        'at': toEpochMillis(at),
      };

  static RenderSummary? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final json = asMap(raw);
    return RenderSummary(
      outcome: asEnum(RenderOutcome.values, json['outcome'], RenderOutcome.rendered),
      codec: asString(json['codec'], ''),
      width: asInt(json['width'], 0),
      height: asInt(json['height'], 0),
      at: asDateTime(json['at'], DateTime.fromMillisecondsSinceEpoch(0, isUtc: true)),
    );
  }
}
