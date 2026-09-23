import '../../project/controllers/project_controller.dart';
import '../../../domain/models/block_catalog.dart';
import '../../../domain/models/credit_block.dart';

class BlockSummary {
  final String title;
  final String meta;
  final String duration;
  const BlockSummary({required this.title, required this.meta, required this.duration});
}

BlockSummary summarizeBlock(CreditBlock b, ProjectState project) {
  final description = describeBlock(b);
  return BlockSummary(title: description.title, meta: description.detail, duration: _blockDuration(b, project));
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
