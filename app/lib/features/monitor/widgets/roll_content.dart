import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';

import '../../../domain/models/credit_block.dart';
import '../../../domain/engine/roll_engine.dart';
import 'roll_block_widgets.dart';

/// Lays out every active block at full render resolution and, after each
/// layout pass, reports each block's top offset (and the total scrollable
/// height) through [onMeasured] — this is the
/// Flutter equivalent of the prototype's `measure()`, which read
/// `offsetTop` off the real DOM after the browser laid the roll out.
/// Reads a [RollContent]'s measurements on demand — for a render tree
/// with no frames scheduled, where [RollContent.onMeasured] never fires.
class RollMeasurer {
  RollContentState? _state;

  /// Where each block sits in the laid-out roll, or null before layout.
  RollMeasurements? measure() => _state?.measure();
}

class RollContent extends StatefulWidget {
  final List<CreditBlock> blocks;
  final RollGeometry geometry;
  final ValueChanged<RollMeasurements>? onMeasured;
  final RollMeasurer? measurer;

  const RollContent({super.key, required this.blocks, required this.geometry, this.onMeasured, this.measurer});

  @override
  State<RollContent> createState() => RollContentState();
}

class RollContentState extends State<RollContent> {
  @override
  void initState() {
    super.initState();
    widget.measurer?._state = this;
    _scheduleMeasure();
  }

  @override
  void didUpdateWidget(covariant RollContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.measurer, widget.measurer)) {
      if (identical(oldWidget.measurer?._state, this)) oldWidget.measurer?._state = null;
      widget.measurer?._state = this;
    }
    _scheduleMeasure();
  }

  @override
  void dispose() {
    if (identical(widget.measurer?._state, this)) widget.measurer?._state = null;
    super.dispose();
  }

  void _scheduleMeasure() {
    if (widget.onMeasured == null) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (measure() case final m?) widget.onMeasured?.call(m);
    });
  }

  /// Where each block sits in the laid-out roll, or null before layout.
  ///
  /// Read straight off the column's children rather than through global
  /// keys, which only resolve in the app's own widget tree — this also has
  /// to work in the exporter's offscreen one.
  RollMeasurements? measure() {
    if (!mounted) return null;
    final box = context.findRenderObject();
    final column = box is RenderProxyBox ? box.child : null;
    if (column is! RenderFlex || !column.hasSize) return null;
    final blockY = <String, double>{};
    var child = column.firstChild;
    for (final b in widget.blocks) {
      if (child == null) break;
      blockY[b.id] = (child.parentData! as FlexParentData).offset.dy;
      child = column.childAfter(child);
    }
    return RollMeasurements(travel: column.size.height + widget.geometry.h, blockY: blockY);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.geometry;
    final sidePad = g.w * .1;
    return SizedBox(
      width: g.w,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final b in widget.blocks)
            Padding(
              key: ValueKey(b.id),
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
