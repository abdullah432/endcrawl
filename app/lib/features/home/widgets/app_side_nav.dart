import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/layout/layout_class.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';
import '../../access/controllers/web_access.dart';
import '../../access/screens/web_access_screen.dart';
import '../../library/controllers/library_controller.dart';

enum HomeDestination { projects, settings }

/// The side rail that replaces the phone's single column on a tablet
/// (T1.1, 220 px) and a desktop browser (D9, 248 px): the wordmark,
/// Projects and Settings, and at its foot a quiet plan status — never a
/// banner. The desktop rail also names the signed-in account.
class AppSideNav extends ConsumerWidget {
  final HomeDestination selected;
  final ValueChanged<HomeDestination> onSelect;

  const AppSideNav({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final desktop = context.layoutClass == LayoutClass.expanded;
    final user = ref.watch(authStateProvider).value;

    return Container(
      width: desktop ? 248 : 220,
      padding: desktop ? const EdgeInsets.fromLTRB(16, 28, 16, 20) : const EdgeInsets.fromLTRB(14, 32, 14, 22),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: .3),
        border: Border(right: BorderSide(color: p.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 22),
            child: Align(
              alignment: Alignment.centerLeft,
              child: EcLogo(size: desktop ? 13 : 12),
            ),
          ),
          _NavItem(
            label: 'Projects',
            selected: selected == HomeDestination.projects,
            desktop: desktop,
            onTap: () => onSelect(HomeDestination.projects),
          ),
          const SizedBox(height: 6),
          _NavItem(
            label: 'Settings',
            selected: selected == HomeDestination.settings,
            desktop: desktop,
            onTap: () => onSelect(HomeDestination.settings),
          ),
          const Spacer(),
          _PlanStatus(desktop: desktop),
          if (desktop && user != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 12, 8, 0),
              child: Row(
                children: [
                  EcAvatar(initials: user.initials, size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user.label,
                          style: context.type.titleS.copyWith(fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (user.email != null && user.email != user.label)
                          Text(
                            user.email!,
                            style: context.type.caption.copyWith(fontSize: 11.5),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool selected;
  final bool desktop;
  final VoidCallback onTap;

  const _NavItem({required this.label, required this.selected, required this.desktop, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final shape = BorderRadius.circular(desktop ? 12 : 14);
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: shape,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: selected ? null : onTap,
          child: Ink(
            height: desktop ? 42 : 46,
            decoration: BoxDecoration(
              color: selected ? p.surface : null,
              borderRadius: shape,
              boxShadow: selected ? p.rowShadow : null,
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: t.row.copyWith(
                  fontSize: desktop ? 14 : 14.5,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? p.ink : p.ink2,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The rail's foot: Pro as a status line, Free with its project count, or
/// — in the web preview — the one quiet way to Pro.
class _PlanStatus extends ConsumerWidget {
  final bool desktop;
  const _PlanStatus({required this.desktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final entitlement = ref.watch(entitlementProvider).value ?? const Entitlement.free();
    final count = ref.watch(projectSummariesProvider).value?.length ?? 0;
    final web = ref.watch(runningOnWebProvider);

    if (ref.watch(webPreviewProvider)) {
      return EcDashedBorder(
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('PREVIEW · FREE', style: t.eyebrow),
              const SizedBox(height: 10),
              Text('Editing on the web needs Pro.', style: t.displayS.copyWith(fontSize: 20, height: 1.1)),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: p.inkSurface,
                    foregroundColor: p.onInk,
                    shape: const StadiumBorder(),
                    textStyle: t.buttonSmall.copyWith(fontSize: 13),
                  ),
                  onPressed: () => WebAccessScreen.open(context),
                  child: const Text('How to get Pro'),
                ),
              ),
            ],
          ),
        ),
      );
    }

    final store = web ? 'Google Play' : AppLinks.storeName;
    final (title, detail) = entitlement.isPro
        ? (desktop ? 'Pro · active' : 'Pro', desktop ? 'Billed through $store' : 'via $store')
        : ('Free', '$count of ${Entitlement.freeProjectLimit} projects · ads on');
    final content = Row(
      children: [
        if (entitlement.isPro) ...[
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: p.ok, shape: BoxShape.circle),
          ),
          SizedBox(width: desktop ? 12 : 10),
        ],
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.titleS.copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
              Text(detail, style: t.caption.copyWith(fontSize: desktop ? 11.5 : 11)),
            ],
          ),
        ),
      ],
    );
    final padding = desktop
        ? const EdgeInsets.symmetric(horizontal: 16, vertical: 14)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);
    if (!entitlement.isPro) {
      return EcDashedBorder(
        radius: 16,
        child: Padding(padding: padding, child: content),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: p.glass,
        border: Border.all(color: p.glassEdge),
        borderRadius: BorderRadius.circular(desktop ? 18 : 16),
      ),
      child: content,
    );
  }
}
