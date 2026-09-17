import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// A pill-shaped choice chip — used for fps options, delimiter candidates,
/// resolution ladder, background/look pickers, etc. Direct visual port of
/// the prototype's `chip(on)` style helper.
class EcChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool mono;
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcRadius.full),
        child: Container(
          height: 34,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: selected ? EcColors.accentWash : EcColors.surfaceRaised,
            borderRadius: BorderRadius.circular(EcRadius.full),
            border: Border.all(color: selected ? EcColors.accentPrimary : EcColors.borderHairline),
          ),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: mono ? EcFonts.mono : EcFonts.ui,
                    fontSize: 11.5,
                    color: selected ? EcColors.accentPrimary : EcColors.textSecondary,
                  ),
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 4), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// A pill-shaped segmented control with a solid highlight, e.g. the
/// Prototype/Tokens or Lock runtime/Lock speed toggles.
class EcSegmented extends StatelessWidget {
  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onChanged;

  const EcSegmented({super.key, required this.labels, required this.selectedIndex, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: EcColors.surfaceRaised,
        borderRadius: BorderRadius.circular(EcRadius.full),
        border: Border.all(color: EcColors.borderHairline),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => onChanged(i),
                  borderRadius: BorderRadius.circular(EcRadius.full),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == selectedIndex ? EcColors.surfaceHi : Colors.transparent,
                      borderRadius: BorderRadius.circular(EcRadius.full),
                    ),
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 12.5,
                        color: i == selectedIndex ? EcColors.textPrimary : EcColors.textTertiary,
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
