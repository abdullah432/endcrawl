import '../../project/controllers/project_controller.dart';
import '../../project/models/credit_block.dart';
import '../../project/models/roll_engine.dart';

class BlockSummary {
  final String title;
  final String meta;
  final String duration;
  const BlockSummary({required this.title, required this.meta, required this.duration});
}

BlockSummary summarizeBlock(CreditBlock b, ProjectState project) {
  String title = '';
  String meta = '';

  switch (b) {
    case TitleBlock v:
      title = v.title;
      meta = '${v.banner.isNotEmpty ? '${v.banner} · ' : ''}title at ${(v.titleScale * 100).round()}% scale';
    case DeptBlock v:
      title = v.header;
      meta = v.names.join(' · ');
    case CastBlock v:
      final cg = computeCastGeometry(v, project.geometry);
      final rowCount = v.rows.whereType<PairCastRow>().length;
      final leader = switch (v.leader) {
        LeaderStyle.dots => 'dotted leaders',
        LeaderStyle.rule => 'hairline rule',
        LeaderStyle.clean => 'clean gutter',
      };
      title = 'Cast';
      meta = '$rowCount rows · $leader${cg.collapse ? ' · stacked' : ' · two-column'}';
    case SongBlock v:
      title = v.songTitle;
      meta = v.artist;
    case ThanksBlock v:
      title = v.header;
      meta = '${v.names.length} names';
    case LogosBlock v:
      title = 'Logo row';
      meta = v.logos.join(' · ');
    case HoldBlock v:
      title = v.lines.isNotEmpty ? v.lines.first : 'Hold card';
      meta = 'hold ${v.hold}s · fade ${v.fadeIn}/${v.fadeOut}s';
    case SpacerBlock v:
      title = 'Spacer';
      meta = '${v.seconds} s';
  }

  return BlockSummary(title: title, meta: meta, duration: _blockDuration(b, project));
}

String _blockDuration(CreditBlock b, ProjectState project) {
  if (b is HoldBlock) return '${(b.fadeIn + b.hold + b.fadeOut).toStringAsFixed(1)}s';
  if (b is SpacerBlock) return '${b.seconds.toStringAsFixed(1)}s';

  final y = project.measurements.blockY[b.id];
  if (y == null) return '—';
  final e = project.engine;
  final ids = project.activeBlocks.map((x) => x.id).toList();
  final i = ids.indexOf(b.id);
  final next = (i >= 0 && i < ids.length - 1) ? (project.measurements.blockY[ids[i + 1]] ?? 0) : (e.travel - e.canvasH);
  final h = (next - y).clamp(0, double.infinity);
  if (e.pps == 0) return '—';
  return '${(h / e.pps).toStringAsFixed(1)}s';
}
