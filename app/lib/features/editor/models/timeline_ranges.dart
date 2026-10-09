import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/credit_block.dart';
import '../../project/controllers/project_controller.dart';

class TimelineRange {
  final String? blockId;
  final String label;
  final double start;
  final double end;
  const TimelineRange(this.blockId, this.label, this.start, this.end);
}

/// Projects measured boundaries through the same engine mapping as seeking.
/// Durations are never normalized to fill the track: black and holds have time.
List<TimelineRange> timelineRanges(ProjectState project) {
  final e = project.engine;
  if (e.totalFrames <= 0) return const [];
  final blocks = project.activeBlocks;
  final ranges = <TimelineRange>[];
  if (e.headFrames > 0) {
    ranges.add(TimelineRange(null, 'Head black', 0, e.headFrames));
  }
  for (var i = 0; i < blocks.length; i++) {
    final b = blocks[i];
    if (b is HoldBlock) {
      for (final segment in e.segments.whereType<HoldSegment>()) {
        if (segment.id == b.id && segment.f1 > segment.f0) {
          ranges.add(TimelineRange(b.id, b.kind.code, segment.f0, segment.f1));
        }
      }
      continue;
    }
    final y = project.measurements.blockY[b.id];
    if (y == null) continue;
    final endY = i + 1 < blocks.length
        ? project.measurements.blockY[blocks[i + 1].id] ?? y
        : e.travel - e.canvasH;
    for (final segment in e.segments.whereType<ScrollSegment>()) {
      final segmentEnd = segment.y0 + (segment.f1 - segment.f0) * e.ppf;
      final from = y.clamp(segment.y0, segmentEnd);
      final to = endY.clamp(segment.y0, segmentEnd);
      if (to > from) {
        ranges.add(
          TimelineRange(
            b.id,
            b.kind.code,
            segment.f0 + (from - segment.y0) / e.ppf,
            segment.f0 + (to - segment.y0) / e.ppf,
          ),
        );
      }
    }
  }
  if (e.tailFrames > 0) {
    ranges.add(
      TimelineRange(
        null,
        'Tail black',
        e.totalFrames - e.tailFrames,
        e.totalFrames,
      ),
    );
  }
  ranges.sort((a, b) => a.start.compareTo(b.start));
  // Scroll travel surrounding a hold or the final visible block also takes time.
  final gaps = <TimelineRange>[];
  for (final segment in e.segments.whereType<ScrollSegment>()) {
    var cursor = segment.f0;
    for (final range in ranges) {
      if (range.end <= segment.f0 || range.start >= segment.f1) continue;
      if (range.start > cursor) {
        gaps.add(TimelineRange(null, 'Scroll', cursor, range.start));
      }
      if (range.end > cursor) cursor = range.end;
    }
    if (cursor < segment.f1) {
      gaps.add(TimelineRange(null, 'Scroll', cursor, segment.f1));
    }
  }
  return [...ranges, ...gaps]..sort((a, b) => a.start.compareTo(b.start));
}
