import 'package:flutter/material.dart';

import '../theme/theme_context.dart';
import '../theme/tokens.dart';

/// A 34 px choice chip — "Selected" / "Option" in the design's Parts board.
/// Used for fps, codecs, split rules, filters and every other one-of-many.
class EcChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final bool mono;

  /// A count or glyph after the label — split-rule counts on 4.2.
  final Widget? trailing;

  const EcChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.mono = false,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final base = mono ? t.mono.copyWith(fontSize: 12) : t.bodyS;
    final shape = BorderRadius.circular(EcRadius.pill);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: EcMotion.fast,
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color: selected ? p.accentWash : p.surface.withValues(alpha: 0.7),
              borderRadius: shape,
              border: Border.all(color: selected ? p.accentLine : p.line),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: base.copyWith(
                      color: selected ? p.accent : p.ink2,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 6), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A segmented control: a tint track with a raised white thumb —
/// "Lock runtime / Lock speed", "Paste & split / Import file".
class EcSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const EcSegmented({super.key, required this.labels, required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(color: p.tint, borderRadius: BorderRadius.circular(EcRadius.pill)),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Semantics(
                selected: i == selectedIndex,
                button: true,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onChanged(i),
                  child: AnimatedContainer(
                    duration: EcMotion.base,
                    curve: EcMotion.easeOut,
                    height: 38,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selectedIndex ? p.surface : Colors.transparent,
                      borderRadius: BorderRadius.circular(EcRadius.pill),
                      boxShadow: i == selectedIndex
                          ? const [BoxShadow(color: Color(0x1F1A1612), offset: Offset(0, 1), blurRadius: 3)]
                          : null,
                    ),
                    child: Text(
                      labels[i],
                      style: t.bodyS.copyWith(
                        fontSize: 13,
                        color: i == selectedIndex ? p.ink : p.muted,
                        fontWeight: i == selectedIndex ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
