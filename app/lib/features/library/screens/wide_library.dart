import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/layout/layout_class.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';
import '../../access/controllers/web_access.dart';
import '../../access/screens/web_access_screen.dart';
import '../../access/widgets/locked_dialog.dart';
import '../../ads/data/ad_service.dart';
import '../../ads/widgets/sponsored_slot.dart';
import '../../export/controllers/export_controller.dart';
import '../../home/widgets/app_side_nav.dart';
import '../../new_project/screens/new_project_sheet.dart';
import '../../plan/controllers/editable_projects.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/plan_navigation.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/widgets/plan_meter.dart';
import '../../plan/widgets/trial_offer_card.dart';
import '../../settings/screens/settings_screen.dart';
import '../controllers/library_controller.dart';
import '../widgets/project_actions_sheet.dart';
import '../widgets/project_tile.dart';
import 'library_screen.dart';

/// T1.1 / T1.2 / D7 / D9 — the library on a tablet or a desktop browser: a
/// side rail and a grid of credit frames, numbered like reels.
///
/// Same data and actions as the phone (`LibraryActions`); only the layout
/// differs. A full free plan puts the plan card in the next grid cell (T1.2),
/// and the web preview adds one quiet banner and a locked "New project"
/// cell (D7).
class WideLibrary extends ConsumerStatefulWidget {
  const WideLibrary({super.key});

  @override
  ConsumerState<WideLibrary> createState() => _WideLibraryState();
}

class _WideLibraryState extends ConsumerState<WideLibrary> {
  final _search = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _search.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = context.layoutClass == LayoutClass.expanded;
    final view = ref.watch(libraryViewProvider);
    final preview = ref.watch(webPreviewProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: EcGround(
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AppSideNav(
                selected: HomeDestination.projects,
                onSelect: (_) =>
                    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
              ),
              Expanded(
                child: Padding(
                  padding: desktop
                      ? const EdgeInsets.fromLTRB(44, 34, 44, 0)
                      : const EdgeInsets.fromLTRB(30, 32, 30, 0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _Header(
                        view: view.value,
                        desktop: desktop,
                        search: _search,
                        searching: _searching,
                        onSearch: _toggleSearch,
                      ),
                      SizedBox(height: desktop ? 22 : 20),
                      if (preview) ...[const _PreviewBanner(), SizedBox(height: desktop ? 22 : 20)],
                      Expanded(
                        child: switch (view) {
                          AsyncValue(:final value?) => _Grid(view: value, query: _search.text.trim(), desktop: desktop),
                          AsyncError(:final error) => Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  error is AppFailure ? error.message : 'Could not open your projects.',
                                  style: context.type.body,
                                ),
                                const SizedBox(height: 16),
                                EcButton.secondary(
                                  label: 'Try again',
                                  size: EcButtonSize.medium,
                                  onPressed: () => ref.invalidate(projectSummariesProvider),
                                ),
                              ],
                            ),
                          ),
                          _ => const Center(
                            child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                          ),
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _search.clear();
  });
}

class _Header extends ConsumerWidget {
  final LibraryView? view;
  final bool desktop;
  final TextEditingController search;
  final bool searching;
  final VoidCallback onSearch;

  const _Header({
    required this.view,
    required this.desktop,
    required this.search,
    required this.searching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final view = this.view;
    final preview = ref.watch(webPreviewProvider);
    final full = !preview && (view?.isFull ?? false);
    final eyebrow = view == null
        ? null
        : desktop
        ? '${view.count} ${view.count == 1 ? 'project' : 'projects'} · ${view.entitlement.isPro ? 'Pro' : 'Free'}'
        // T1.1 names the unit where the phone's narrower header can't.
        : view.limit == null && view.trialDaysLeft == null
        ? 'Reel · ${plural(view.count, 'project')} · Pro'
        : view.reelLabel();

    final searchField = Container(
      height: desktop ? 44 : 48,
      width: desktop ? 280 : 240,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: p.glass,
        border: Border.all(color: p.glassEdge),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(Icons.search_rounded, size: 18, color: p.muted),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: search,
              autofocus: !desktop,
              style: t.bodyS.copyWith(fontSize: 13.5, color: p.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search projects',
                hintStyle: t.bodyS.copyWith(fontSize: 13.5, color: p.muted),
              ),
            ),
          ),
          if (!desktop)
            GestureDetector(
              onTap: onSearch,
              child: Icon(Icons.close_rounded, size: 18, color: p.muted),
            ),
        ],
      ),
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null) EcEyebrow(eyebrow),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text('Projects', style: t.displayXL.copyWith(fontSize: desktop ? 52 : 48, height: 1)),
              ),
            ],
          ),
        ),
        if (desktop || searching)
          searchField
        else
          EcCircleButton.glass(icon: Icons.search_rounded, tooltip: 'Search projects', size: 48, onPressed: onSearch),
        SizedBox(width: desktop ? 10 : 8),
        if (view != null)
          preview
              ? Tooltip(
                  message: 'New projects need Pro on the web',
                  child: _LockedNewButton(onTap: () => lockedOnWeb(context, LockedAction.newProject)),
                )
              : EcButton(
                  label: 'New project',
                  variant: full ? EcButtonVariant.secondary : EcButtonVariant.primary,
                  size: EcButtonSize.medium,
                  expand: false,
                  leading: Icon(Icons.add_rounded, size: 18, color: full ? p.ink : p.onInk),
                  onPressed: () => full ? handleSlotsFull(context) : _newProject(context, view),
                ),
      ],
    );
  }
}

void _newProject(BuildContext context, LibraryView view) =>
    NewProjectSheet.show(context, slotLabel: 'Reel ${view.nextReel.toString().padLeft(2, '0')}');

class _LockedNewButton extends StatelessWidget {
  final VoidCallback onTap;
  const _LockedNewButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Material(
      color: p.tint,
      shape: StadiumBorder(side: BorderSide(color: p.line)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.lock_outline_rounded, size: 16, color: p.muted),
                const SizedBox(width: 8),
                Text(
                  'New project',
                  style: t.buttonSmall.copyWith(fontSize: 13.5, fontWeight: FontWeight.w700, color: p.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// D7: one quiet banner explains the preview — no countdown, nag or price.
class _PreviewBanner extends StatelessWidget {
  const _PreviewBanner();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        color: p.accentWash,
        border: Border.all(color: p.accentLine),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: p.surface, shape: BoxShape.circle),
            child: Icon(Icons.visibility_outlined, size: 18, color: p.accent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('You’re previewing LastReel on the web.', style: t.titleS.copyWith(fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(
                  'Open and play any project. Editing, new projects and export unlock with Pro.',
                  style: t.bodyS.copyWith(fontSize: 13),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          EcButton(
            label: 'How to get Pro',
            variant: EcButtonVariant.ink,
            size: EcButtonSize.small,
            expand: false,
            onPressed: () => WebAccessScreen.open(context),
          ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  final LibraryView view;
  final String query;
  final bool desktop;

  const _Grid({required this.view, required this.query, required this.desktop});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(libraryUiProvider);
    final now = ref.watch(clockProvider)();
    final readOnly = ref.watch(readOnlyProjectIdsProvider);
    final preview = ref.watch(webPreviewProvider);
    final actions = LibraryActions(context, ref, view);

    final needle = query.toLowerCase();
    final items = [
      ...view.items.where((i) => i.summary.id == ui.highlightedId),
      ...view.items.where((i) => i.summary.id != ui.highlightedId),
    ].where((i) => needle.isEmpty || i.summary.title.toLowerCase().contains(needle)).toList();

    final showPlanCell = !preview && !view.entitlement.isPro && view.isFull && !ui.freeingSlot && needle.isEmpty;
    final frameHeight = preview ? 180.0 : (desktop ? 168.0 : 150.0);
    final gap = desktop ? 20.0 : 16.0;

    final cells = <Widget>[
      for (final item in items)
        ProjectTile(
          item: item,
          now: now,
          frameHeight: frameHeight,
          highlighted: item.summary.id == ui.highlightedId,
          readOnly: readOnly.contains(item.summary.id),
          preview: preview,
          renderProgress: ref.watch(renderProgressProvider(item.summary.id)),
          onOpen: () => actions.open(item),
          onMore: preview ? null : (anchor) => _menu(anchor, actions, item),
        ),
      if (showPlanCell) _PlanCell(used: view.count),
      if (preview && needle.isEmpty) const _LockedNewCell(),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = constraints.maxWidth >= 760 ? 3 : (constraints.maxWidth >= 460 ? 2 : 1);
        return CustomScrollView(
          slivers: [
            if (ui.freeingSlot)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: EcNotice(
                    tone: EcTone.accent,
                    icon: Icons.backspace_outlined,
                    title: 'Delete a project to free a slot.',
                    body: 'Undo stays available for ten seconds after each delete.',
                    actions: [
                      EcButton.secondary(
                        label: 'Done',
                        size: EcButtonSize.small,
                        onPressed: () => ref.read(libraryUiProvider.notifier).setFreeingSlot(false),
                      ),
                    ],
                  ),
                ),
              ),
            if (items.isEmpty && needle.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Text('No projects match “$query”.', textAlign: TextAlign.center, style: context.type.body),
                ),
              )
            else if (cells.isEmpty)
              SliverToBoxAdapter(child: _EmptyCell(desktop: desktop))
            else
              SliverGrid(
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: columns,
                  mainAxisSpacing: gap,
                  crossAxisSpacing: gap,
                  mainAxisExtent: frameHeight + 82,
                ),
                delegate: SliverChildListDelegate(cells),
              ),
            if (view.entitlement.trialEndsAt case final endsAt? when view.trialDaysLeft != null)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.only(top: gap),
                  child: TrialReminderRow(
                    daysLeft: view.trialDaysLeft!,
                    endsAt: endsAt,
                    limit: Entitlement.freeProjectLimit,
                  ),
                ),
              ),
            if (!showPlanCell && !preview)
              SliverToBoxAdapter(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 560),
                    child: const SponsoredSlot(AdPlacement.library, gap: 20),
                  ),
                ),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 32)),
          ],
        );
      },
    );
  }

  /// T1.3: the action menu anchors to the card's "···". Delete is red and
  /// set apart from the everyday actions.
  Future<void> _menu(BuildContext anchor, LibraryActions actions, LibraryItem item) async {
    final p = anchor.palette;
    final t = anchor.type;
    final box = anchor.findRenderObject()! as RenderBox;
    final overlay = Overlay.of(anchor).context.findRenderObject()! as RenderBox;
    final rect = Rect.fromPoints(
      box.localToGlobal(Offset.zero, ancestor: overlay),
      box.localToGlobal(box.size.bottomRight(Offset.zero), ancestor: overlay),
    );
    PopupMenuItem<ProjectAction> entry(ProjectAction value, String label, {bool destructive = false}) => PopupMenuItem(
      value: value,
      height: 46,
      child: Text(
        label,
        style: t.row.copyWith(
          fontSize: 14,
          fontWeight: value == ProjectAction.open ? FontWeight.w600 : FontWeight.w500,
          color: destructive ? p.warn : p.ink,
        ),
      ),
    );
    final action = await showMenu<ProjectAction>(
      context: anchor,
      position: RelativeRect.fromRect(rect, Offset.zero & overlay.size),
      color: p.surface,
      elevation: 12,
      shadowColor: const Color(0x55000000),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      constraints: const BoxConstraints(minWidth: 220),
      items: [
        entry(ProjectAction.open, 'Open'),
        entry(ProjectAction.rename, 'Rename…'),
        entry(ProjectAction.duplicate, 'Duplicate'),
        const PopupMenuDivider(),
        entry(ProjectAction.delete, 'Delete…', destructive: true),
      ],
    );
    switch (action) {
      case ProjectAction.open:
        actions.open(item);
      case ProjectAction.rename:
        await actions.rename(item);
      case ProjectAction.duplicate:
        await actions.duplicate(item);
      case ProjectAction.delete:
        await actions.delete(item);
      case null:
        break;
    }
  }
}

/// T1.2: the plan card takes the cell where a new project would go. One
/// way to the Pro screen; no prices or offers here.
class _PlanCell extends ConsumerWidget {
  final int used;
  const _PlanCell({required this.used});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    const limit = Entitlement.freeProjectLimit;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      decoration: BoxDecoration(color: p.surface, borderRadius: BorderRadius.circular(22), boxShadow: p.glassShadow),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('FREE PLAN', style: t.eyebrow.copyWith(fontSize: 9.5))),
              Text('$used OF $limit PROJECTS', style: t.eyebrow.copyWith(fontSize: 9.5)),
            ],
          ),
          const SizedBox(height: 8),
          PlanMeter(used: used.clamp(0, limit), limit: limit, thickness: 3),
          const SizedBox(height: 12),
          Text('Both free projects are in use.', style: t.displayS.copyWith(fontSize: 22, height: 1.1)),
          const SizedBox(height: 6),
          Expanded(
            child: Text(
              'Nothing is deleted and nothing expires. Pro adds unlimited projects, ProRes and 4K exports, and no ads.',
              style: t.bodyS.copyWith(fontSize: 12, color: p.ink2, height: 1.4),
              overflow: TextOverflow.fade,
            ),
          ),
          EcButton(
            label: 'See LastReel Pro',
            variant: EcButtonVariant.ink,
            size: EcButtonSize.small,
            expand: true,
            onPressed: () => ProSheet.show(context, source: PlanSource.library),
          ),
          TextButton(
            style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
            onPressed: () => ref.read(libraryUiProvider.notifier).setFreeingSlot(true),
            child: Text('Free up a slot', style: t.buttonSmall.copyWith(fontSize: 13, color: p.accent)),
          ),
        ],
      ),
    );
  }
}

/// D7: where a new project would go — locked, and saying why.
class _LockedNewCell extends StatelessWidget {
  const _LockedNewCell();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return EcDashedBorder(
      radius: 22,
      onTap: () => lockedOnWeb(context, LockedAction.newProject),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline_rounded, size: 20, color: p.muted),
            const SizedBox(height: 10),
            Text('New project', style: t.displayS.copyWith(fontSize: 22)),
            const SizedBox(height: 8),
            Text(
              'Start projects here with Pro, or on your phone with the free plan.',
              textAlign: TextAlign.center,
              style: t.bodyS.copyWith(color: p.muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// No projects yet: the way in is a new project.
class _EmptyCell extends StatelessWidget {
  final bool desktop;
  const _EmptyCell({required this.desktop});

  @override
  Widget build(BuildContext context) {
    final t = context.type;
    return Padding(
      padding: const EdgeInsets.only(top: 40),
      child: Column(
        children: [
          Text('No projects yet.', style: t.displayM),
          const SizedBox(height: 8),
          Text(
            'Start one from a template — change anything later.',
            style: t.body.copyWith(color: context.palette.muted),
          ),
          const SizedBox(height: 18),
          EcButton(
            label: 'New project',
            size: EcButtonSize.medium,
            expand: false,
            leading: Icon(Icons.add_rounded, size: 18, color: context.palette.onInk),
            onPressed: () => NewProjectSheet.show(context, slotLabel: 'Reel 01'),
          ),
        ],
      ),
    );
  }
}
