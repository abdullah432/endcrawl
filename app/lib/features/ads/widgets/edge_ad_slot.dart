import 'package:flutter/widgets.dart';

import '../../home/tablet_layout.dart';
import '../data/ad_service.dart';
import 'sponsored_slot.dart';

/// One static ad at the edge of a tablet working screen (T8.3): its own
/// card at the foot of the editor's side column and under the Timing &
/// Look panel — the same place on both, so moving between them nothing
/// jumps. It never touches the monitor, the scrubber or a field.
///
/// [column] is a 372-wide side column (landscape): the compact card.
/// Otherwise the full-width portrait strip at the bottom edge (P3.1, P5.2).
///
/// Hidden while the keyboard is up, kept loaded so it comes back without a
/// new request. Nothing on phones, the web or Pro.
class EdgeAdSlot extends StatefulWidget {
  final AdPlacement placement;
  final bool column;

  /// Space above the slot, kept only while the slot is.
  final double gap;

  const EdgeAdSlot(this.placement, {super.key, required this.column, this.gap = 12});

  @override
  State<EdgeAdSlot> createState() => _EdgeAdSlotState();
}

class _EdgeAdSlotState extends State<EdgeAdSlot> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // The keyboard coming or going.
  @override
  void didChangeMetrics() => setState(() {});

  @override
  Widget build(BuildContext context) {
    if (!context.isTablet) return const SizedBox.shrink();
    // The window's own insets: a Scaffold takes the keyboard out of its
    // body's MediaQuery once it has made room for it.
    final typing = View.of(context).viewInsets.bottom > 0;
    return Visibility(
      visible: !typing,
      maintainState: true,
      child: TabletAdSlot(
        widget.placement,
        layout: widget.column ? AdLayout.compact : AdLayout.strip,
        portrait: !widget.column,
        gap: widget.gap,
      ),
    );
  }
}
