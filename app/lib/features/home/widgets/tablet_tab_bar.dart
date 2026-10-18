import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import 'app_side_nav.dart';
import 'nav_icons.dart';

/// The portrait tablet's main navigation (P1.1): Projects and Settings,
/// 84 tall, each an icon in a 64 × 32 pill above its label. The rail's job
/// in landscape; never shown in the editor flow.
class TabletTabBar extends StatelessWidget {
  final HomeDestination selected;
  final ValueChanged<HomeDestination> onSelect;

  const TabletTabBar({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      decoration: BoxDecoration(
        color: p.sheet.withValues(alpha: .92),
        border: Border(top: BorderSide(color: p.line)),
      ),
      padding: EdgeInsets.only(bottom: 8 + MediaQuery.paddingOf(context).bottom),
      child: SizedBox(
        height: 76,
        child: Row(
          children: [
            for (final (tab, label, icon) in const [
              (HomeDestination.projects, 'Projects', NavIcon.projects),
              (HomeDestination.settings, 'Settings', NavIcon.settings),
            ])
              Expanded(
                child: _Tab(label: label, icon: icon, selected: tab == selected, onTap: () => onSelect(tab)),
              ),
          ],
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final NavIcon icon;
  final bool selected;
  final VoidCallback onTap;

  const _Tab({required this.label, required this.icon, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: selected ? null : onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 64,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? p.accentWash : Colors.transparent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: NavIconView(icon, size: 18, color: selected ? p.accent : p.muted),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: t.bodyS.copyWith(
                fontSize: 12,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? p.ink : p.muted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
