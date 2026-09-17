import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../project/controllers/project_controller.dart';
import '../../project/models/credit_block.dart';
import '../../project/models/roll_engine.dart';
import 'roll_block_widgets.dart';

/// Lays out every active block at full render resolution and, after each
/// layout pass, reports each block's top offset (and the total scrollable
/// height) back to [ProjectController.updateMeasurements] — this is the
/// Flutter equivalent of the prototype's `measure()`, which read
/// `offsetTop` off the real DOM after the browser laid the roll out.
class RollContent extends ConsumerStatefulWidget {
  final List<CreditBlock> blocks;
  final RollGeometry geometry;

  const RollContent({super.key, required this.blocks, required this.geometry});

  @override
  ConsumerState<RollContent> createState() => _RollContentState();
}

class _RollContentState extends ConsumerState<RollContent> {
  final _columnKey = GlobalKey();
  final Map<String, GlobalKey> _blockKeys = {};

  GlobalKey _keyFor(String id) => _blockKeys.putIfAbsent(id, () => GlobalKey());

  @override
  void initState() {
    super.initState();
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant RollContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    _scheduleMeasure();
  }

  void _scheduleMeasure() {
    SchedulerBinding.instance.addPostFrameCallback((_) => _measure());
  }

  void _measure() {
    if (!mounted) return;
    final columnBox = _columnKey.currentContext?.findRenderObject() as RenderBox?;
    if (columnBox == null || !columnBox.hasSize) return;
    final blockY = <String, double>{};
    for (final b in widget.blocks) {
      final key = _blockKeys[b.id];
      final box = key?.currentContext?.findRenderObject() as RenderBox?;
      if (box == null || !box.hasSize) continue;
      final offset = box.localToGlobal(Offset.zero, ancestor: columnBox);
      blockY[b.id] = offset.dy;
    }
    final travel = columnBox.size.height + widget.geometry.h;
    ref.read(projectControllerProvider.notifier).updateMeasurements(RollMeasurements(travel: travel, blockY: blockY));
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.geometry;
    final sidePad = g.w * .1;
    return SizedBox(
      width: g.w,
      child: Column(
        key: _columnKey,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in widget.blocks)
            Padding(
              key: _keyFor(b.id),
              padding: EdgeInsets.only(
                left: sidePad,
                right: sidePad,
                bottom: (b is SpacerBlock || b is HoldBlock) ? 0 : g.base * 2.4,
              ),
              child: buildRollBlockContent(b, g),
            ),
        ],
      ),
    );
  }
}
