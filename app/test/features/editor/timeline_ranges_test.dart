import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/engine/roll_engine.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/project.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';
import 'package:lastreel/features/editor/models/timeline_ranges.dart';

void main() {
  test(
    'timeline projects engine holds, scroll travel, spacers and black without muted blocks',
    () {
      final project = Project.create(
        settings: const ProjectSettings(ppf: 4, fps: 24),
        blocks: const [
          TitleBlock(id: 'title'),
          SpacerBlock(id: 'gap', seconds: 1),
          HoldBlock(id: 'hold', fadeIn: .21, hold: .61, fadeOut: .21),
          TitleBlock(id: 'muted', muted: true),
          NameListBlock(id: 'names'),
        ],
      );
      final empty = ProjectState(project: project);
      final height = empty.geometry.h;
      final state = empty.copyWith(
        measurements: RollMeasurements(
          blockY: {'title': 0, 'gap': 100, 'hold': 196, 'names': 196 + height},
          travel: 396 + height * 2,
        ),
      );
      final engine = state.engine;
      final ranges = timelineRanges(state);
      final hold = ranges.singleWhere((r) => r.blockId == 'hold');
      final segment = engine.segments.whereType<HoldSegment>().single;
      expect(hold.start, segment.f0);
      expect(hold.end, segment.f1);
      expect(ranges.any((r) => r.blockId == 'gap'), true);
      expect(ranges.any((r) => r.blockId == 'muted'), false);
      expect(ranges.first.label, 'Head black');
      expect(ranges.last.label, 'Tail black');
      expect(
        ranges.fold<double>(0, (sum, r) => sum + r.end - r.start),
        closeTo(engine.totalFrames, 1e-6),
      );
      for (var i = 1; i < ranges.length; i++) {
        expect(ranges[i].start, closeTo(ranges[i - 1].end, 1e-6));
      }
    },
  );
}
