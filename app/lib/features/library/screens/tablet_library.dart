import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/theme/ec_type.dart';
import '../../../core/utils/formatting.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_dashed_border.dart';
import '../../../core/widgets/ec_logo.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';
import '../../ads/data/ad_service.dart';
import '../../ads/widgets/sponsored_slot.dart';
import '../../export/controllers/export_controller.dart';
import '../../home/tablet_layout.dart';
import '../../home/widgets/app_side_nav.dart';
import '../../new_project/screens/new_project_sheet.dart';
import '../../plan/controllers/editable_projects.dart';
import '../../plan/controllers/plan_controller.dart';
import '../../plan/plan_navigation.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../plan/widgets/plan_meter.dart';
import '../../plan/widgets/trial_offer_card.dart';
import '../controllers/library_controller.dart';
import '../widgets/project_actions_sheet.dart';
import '../widgets/project_tile.dart';
import '../widgets/tablet_project_menu.dart';
import 'library_screen.dart';

/// T1.1 / T1.2 / T8.1 / T8.2 · P1.1 / P1.2 — the Projects tab on a tablet.
///
/// Same data and actions as the phone (`LibraryActions`); only the layout
/// differs. Landscape: three across, and on Free the plan card or a dashed
/// "New project" takes the next cell. Portrait: three across on Pro; on
/// Free two large cards, then the plan card across the full width.
///
/// On Free the ad strip (`library_foot`) is pinned to the foot at 0, 1 and
/// 2 of 2 projects — never between cards — so it never moves as projects
/// come and go.
class TabletLibrary extends ConsumerStatefulWidget {
  const TabletLibrary({super.key});

  @override
  ConsumerState<TabletLibrary> createState() => _TabletLibraryState();
}

class _TabletLibraryState extends ConsumerState<TabletLibrary> {
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

  void _toggleSearch() => setState(() {
    _searching = !_searching;
    if (!_searching) _search.clear();
  });

  @override
  Widget build(BuildContext context) {
    final portrait = context.tabletLayout == TabletLayout.portrait;
    final view = ref.watch(libraryViewProvider);
    final value = view.value;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (portrait) _PortraitTopBar(view: value),
        Expanded(
          child: Padding(
            padding: portrait ? const EdgeInsets.fromLTRB(24, 8, 24, 24) : const EdgeInsets.fromLTRB(28, 32, 28, 26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Header(
                  view: value,
                  portrait: portrait,
                  search: _search,
                  searching: _searching,
                  onSearch: _toggleSearch,
                ),
                const SizedBox(height: 20),
                Expanded(
                  child: switch (view) {
                    AsyncValue(:final value?) => _Grid(view: value, query: _search.text.trim(), portrait: portrait),
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
                // Pinned to the foot; collapses with no gap if nothing fills it.
                // Only while this tab shows, so a hidden tab requests no ad.
                if (value != null && ref.watch(homeTabProvider) == HomeDestination.projects) ...[
                  TabletAdSlot(AdPlacement.library, layout: AdLayout.strip, portrait: portrait, gap: 20),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// P1.1: the wordmark, and the plan on the right — "Free · 2 of 2", "Pro".
class _PortraitTopBar extends StatelessWidget {
  final LibraryView? view;
  const _PortraitTopBar({required this.view});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final view = this.view;
    final plan = view == null
        ? ''
        : view.trialDaysLeft != null
        ? 'Pro trial'
        : view.entitlement.isPro
        ? 'Pro'
        : view.limit == null
        ? 'Free'
        : 'Free · ${view.count} of ${view.limit}';
    return Container(
      height: 72,
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Row(
        children: [
          const EcLogo(size: 12),
          const Spacer(),
          Text(
            plan,
            style: context.type.bodyS.copyWith(fontWeight: FontWeight.w600, color: p.ink2),
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final LibraryView? view;
  final bool portrait;
  final TextEditingController search;
  final bool searching;
  final VoidCallback onSearch;

  const _Header({
    required this.view,
    required this.portrait,
    required this.search,
    required this.searching,
    required this.onSearch,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final view = this.view;
    final full = view?.isFull ?? false;
    final eyebrow = view == null
        ? null
        : view.limit == null && view.trialDaysLeft == null
        ? 'Reel · ${plural(view.count, 'project')} · ${view.entitlement.isPro ? 'Pro' : 'Free'}'
        : view.reelLabel();
    // Search is for a long reel: the free plan holds two projects.
    final canSearch = view != null && view.limit == null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (eyebrow != null)
                Text(caps(eyebrow), style: t.eyebrow.copyWith(fontSize: 10.5, letterSpacing: 10.5 * .14)),
              const SizedBox(height: 6),
              Semantics(
                header: true,
                child: Text('Projects', style: t.displayXL.copyWith(fontSize: portrait ? 52 : 48, height: 1)),
              ),
            ],
          ),
        ),
        if (canSearch) ...[
          if (searching)
            _SearchField(controller: search, onClose: onSearch)
          else
            EcCircleButton.glass(icon: Icons.search_rounded, tooltip: 'Search projects', size: 48, onPressed: onSearch),
          const SizedBox(width: 8),
        ],
        if (view != null)
          EcButton(
            label: 'New project',
            variant: full ? EcButtonVariant.secondary : EcButtonVariant.primary,
            size: EcButtonSize.medium,
            height: 48,
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

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final VoidCallback onClose;
  const _SearchField({required this.controller, required this.onClose});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Container(
      height: 48,
      width: 240,
      padding: const EdgeInsets.only(left: 16, right: 4),
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
              controller: controller,
              autofocus: true,
              style: t.bodyS.copyWith(fontSize: 13.5, color: p.ink),
              decoration: InputDecoration(
                isCollapsed: true,
                border: InputBorder.none,
                hintText: 'Search projects',
                hintStyle: t.bodyS.copyWith(fontSize: 13.5, color: p.muted),
              ),
            ),
          ),
          IconButton(
            tooltip: 'Close search',
            onPressed: onClose,
            icon: Icon(Icons.close_rounded, size: 18, color: p.muted),
          ),
        ],
      ),
    );
  }
}

class _Grid extends ConsumerWidget {
  final LibraryView view;
  final String query;
  final bool portrait;

  const _Grid({required this.view, required this.query, required this.portrait});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(libraryUiProvider);
    final now = ref.watch(clockProvider)();
    final readOnly = ref.watch(readOnlyProjectIdsProvider);
    final actions = LibraryActions(context, ref, view);

    final needle = query.toLowerCase();
    final items = [
      ...view.items.where((i) => i.summary.id == ui.highlightedId),
      ...view.items.where((i) => i.summary.id != ui.highlightedId),
    ].where((i) => needle.isEmpty || i.summary.title.toLowerCase().contains(needle)).toList();

    final free = !view.entitlement.isPro && view.limit != null;
    final showPlan = free && view.isFull && !ui.freeingSlot && needle.isEmpty;
    // P1.2: on Free the portrait library shows two large cards.
    final large = portrait && free;
    final gap = portrait ? 14.0 : 16.0;
    final frame = large ? 220.0 : (portrait ? 180.0 : 150.0);
    final footerPadding = large ? const EdgeInsets.fromLTRB(16, 14, 10, 16) : const EdgeInsets.fromLTRB(14, 12, 8, 14);
    final titleSize = large ? 23.0 : 21.0;
    const moreHeight = 26.0;
    final cellHeight =
        frame + ProjectTile.footerHeight(titleSize: titleSize, padding: footerPadding, moreHeight: moreHeight);

    final cells = <Widget>[
      for (final item in items)
        Builder(
          builder: (cell) {
            ProjectTile tile({void Function(BuildContext)? onMore}) => ProjectTile(
              item: item,
              now: now,
              frameHeight: frame,
              titleSize: titleSize,
              nameSize: large ? 18 : 15,
              footerPadding: footerPadding,
              moreHeight: moreHeight,
              highlighted: item.summary.id == ui.highlightedId,
              readOnly: readOnly.contains(item.summary.id),
              renderProgress: ref.watch(renderProgressProvider(item.summary.id)),
              onOpen: () => actions.open(item),
              onMore: onMore,
            );
            return SizedBox(
              height: cellHeight,
              child: tile(onMore: (_) => _menu(cell, actions, item, tile())),
            );
          },
        ),
      // T1.2: the plan card takes the next cell; P1.2 gives it a row.
      if (showPlan && !portrait) _PlanCard(used: view.count, limit: view.limit!),
      // T8.2: while a slot is open, the next cell is where it goes.
      if (needle.isEmpty && !ui.freeingSlot && ((free && !view.isFull) || items.isEmpty))
        _NewCell(height: cellHeight, slotsLeft: view.slotsLeft, onTap: () => _newProject(context, view)),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = large ? 2 : ((constraints.maxWidth + gap) / (250 + gap)).floor().clamp(2, 4);
        return ListView(
          padding: EdgeInsets.zero,
          children: [
            if (ui.freeingSlot) ...[
              EcNotice(
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
              SizedBox(height: gap),
            ],
            if (items.isEmpty && needle.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 40),
                child: Text('No projects match “$query”.', textAlign: TextAlign.center, style: context.type.body),
              )
            else
              for (var start = 0; start < cells.length; start += columns) ...[
                if (start > 0) SizedBox(height: gap),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var i = start; i < start + columns; i++) ...[
                      if (i > start) SizedBox(width: gap),
                      Expanded(child: i < cells.length ? cells[i] : const SizedBox.shrink()),
                    ],
                  ],
                ),
              ],
            if (showPlan && portrait) ...[
              SizedBox(height: gap + 6),
              _PlanCard(used: view.count, limit: view.limit!, wide: true),
            ],
            if (view.entitlement.trialEndsAt case final endsAt? when view.trialDaysLeft != null) ...[
              SizedBox(height: gap),
              TrialReminderRow(daysLeft: view.trialDaysLeft!, endsAt: endsAt, limit: Entitlement.freeProjectLimit),
            ],
          ],
        );
      },
    );
  }
}

/// T1.3: the card's actions, anchored to it.
Future<void> _menu(BuildContext cell, LibraryActions actions, LibraryItem item, Widget card) async {
  final action = await showTabletProjectMenu(cell, card: card);
  switch (action) {
    case ProjectAction.open:
      actions.open(item);
    case ProjectAction.rename:
      await actions.rename(item);
    case ProjectAction.duplicate:
      await actions.duplicate(item);
    case ProjectAction.export:
      actions.export(item);
    case ProjectAction.delete:
      await actions.delete(item);
    case null:
      break;
  }
}

/// T1.2 / P1.2: both free projects are in use. One way to the Pro screen,
/// no prices or offers; nothing is ever deleted at the limit.
class _PlanCard extends ConsumerWidget {
  final int used;
  final int limit;

  /// P1.2: across the full width, the buttons on the right.
  final bool wide;

  const _PlanCard({required this.used, required this.limit, this.wide = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final eyebrow = t.eyebrow.copyWith(fontSize: 10, letterSpacing: 10 * .12);
    final copy = <Widget>[
      Row(
        children: [
          Expanded(child: Text('FREE PLAN', style: eyebrow)),
          Text(caps('${used.clamp(0, limit)} of ${plural(limit, 'project')}'), style: eyebrow),
        ],
      ),
      SizedBox(height: wide ? 10 : 14),
      PlanMeter(used: used.clamp(0, limit), limit: limit, thickness: 5, gap: 4, fill: p.ink),
      SizedBox(height: wide ? 10 : 14),
      Text('Both free projects are in use.', style: t.displayS.copyWith(fontSize: 26, height: 1.05)),
      SizedBox(height: wide ? 10 : 14),
      Text(
        wide
            ? 'Nothing is deleted and nothing expires. Pro adds unlimited projects, ProRes and 4K, and no ads.'
            : 'Nothing is deleted and nothing expires. Pro adds unlimited projects, ProRes and 4K exports, and no ads.',
        style: t.body.copyWith(fontSize: 13, height: 1.5, color: p.ink2),
      ),
    ];
    final pro = EcButton(
      label: 'See LastReel Pro',
      variant: EcButtonVariant.ink,
      size: EcButtonSize.medium,
      height: 46,
      expand: !wide,
      onPressed: () => ProSheet.show(context, source: PlanSource.library),
    );
    final freeUp = TextButton(
      style: TextButton.styleFrom(minimumSize: const Size(44, 36)),
      onPressed: () => ref.read(libraryUiProvider.notifier).setFreeingSlot(true),
      child: Text('Free up a slot', style: t.buttonSmall.copyWith(fontSize: 13, color: p.accent)),
    );
    return Container(
      padding: wide ? const EdgeInsets.symmetric(horizontal: 24, vertical: 22) : const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(22),
      ),
      child: wide
          ? Row(
              children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: copy),
                ),
                const SizedBox(width: 24),
                Column(mainAxisSize: MainAxisSize.min, children: [pro, const SizedBox(height: 8), freeUp]),
              ],
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [...copy, const SizedBox(height: 14), pro, const SizedBox(height: 14), freeUp],
            ),
    );
  }
}

/// T8.2: a dashed "New project" where the next project goes, saying how
/// many free slots are left.
class _NewCell extends StatelessWidget {
  final double height;
  final int? slotsLeft;
  final VoidCallback onTap;

  const _NewCell({required this.height, required this.slotsLeft, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final left = slotsLeft;
    return Semantics(
      button: true,
      label: 'New project',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: EcDashedBorder(
          radius: 22,
          onTap: onTap,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: p.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: p.line),
                  ),
                  child: Icon(Icons.add_rounded, size: 22, color: p.ink2),
                ),
                const SizedBox(height: 10),
                Text('New project', style: t.titleS.copyWith(fontSize: 14, color: p.ink2)),
                if (left != null) ...[
                  const SizedBox(height: 10),
                  Text('${plural(left, 'free slot')} left', style: t.mono.copyWith(fontSize: 10.5, color: p.muted)),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
