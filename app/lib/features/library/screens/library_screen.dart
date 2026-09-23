import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_ad_slot.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../core/widgets/ec_toast.dart';
import '../../../domain/models/entitlement.dart';
import '../../new_project/new_project_flow.dart';
import '../../new_project/screens/new_project_sheet.dart';
import '../../new_project/widgets/template_list.dart';
import '../../plan/plan_navigation.dart';
import '../../plan/screens/pro_sheet.dart';
import '../../project/project_navigation.dart';
import '../../settings/screens/settings_screen.dart';
import '../controllers/library_controller.dart';
import '../widgets/delete_project_sheet.dart';
import '../widgets/project_actions_sheet.dart';
import '../widgets/project_card.dart';
import '../widgets/rename_sheet.dart';
import '../widgets/slot_card.dart';

/// 1.1 / 1.2 / 1.7 — the home screen, where finished work lives.
///
/// Every project is a credit frame numbered like a reel. On the free plan
/// the next empty reel is shown as a slot, so the cap is visible long before
/// it blocks anyone. With no projects yet, the empty state *is* the
/// template picker — no illustration, no "get started" button.
class LibraryScreen extends ConsumerWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(libraryViewProvider);

    return EcScaffold(
      scrollable: false,
      padding: EdgeInsets.zero,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _Header(view: view.value),
          Expanded(
            child: switch (view) {
              AsyncValue(:final value?) when value.items.isEmpty => _EmptyLibrary(view: value),
              AsyncValue(:final value?) => _ProjectList(view: value),
              AsyncError(:final error) => _ErrorState(
                  message: error is AppFailure ? error.message : 'Could not open your projects.',
                  onRetry: () => ref.invalidate(projectSummariesProvider),
                ),
              _ => const Center(child: SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2))),
            },
          ),
        ],
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  final LibraryView? view;
  const _Header({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    final user = ref.watch(authStateProvider).value;
    final view = this.view;
    final full = view?.isFull ?? false;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (view != null) EcEyebrow(view.reelLabel, color: full ? p.warn : null),
                const SizedBox(height: 8),
                Text('Projects', style: t.displayXL),
              ],
            ),
          ),
          if (user != null)
            EcAvatar(
              initials: user.initials,
              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
            ),
          // No "+ New" on the empty library: the template list below is the
          // way in.
          if (view != null && view.items.isNotEmpty) ...[
            const SizedBox(width: 8),
            EcButton(
              label: 'New',
              variant: full ? EcButtonVariant.secondary : EcButtonVariant.primary,
              size: EcButtonSize.medium,
              leading: Icon(Icons.add_rounded, size: 18, color: full ? p.ink2 : p.onInk),
              onPressed: () => _startNew(context, view),
            ),
          ],
        ],
      ),
    );
  }

  void _startNew(BuildContext context, LibraryView view) {
    if (view.isFull) {
      handleSlotsFull(context);
      return;
    }
    final label = view.limit == null ? 'reel ${view.nextReel}' : 'slot ${view.nextReel} of ${view.limit}';
    NewProjectSheet.show(context, slotLabel: label);
  }
}

class _EmptyLibrary extends ConsumerWidget {
  final LibraryView view;
  const _EmptyLibrary({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.type;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Pick a starting point.', style: t.displayS.copyWith(fontStyle: FontStyle.italic, height: 1.1)),
              const SizedBox(height: 6),
              Text('Change anything later. Every project stays here until you delete it.', style: t.bodyS.copyWith(color: context.palette.muted)),
            ],
          ),
        ),
        TemplateList(onPick: (template) => startNewProject(context, template)),
        if (view.entitlement.showsAds) ...[
          const SizedBox(height: 28),
          EcAdSlot(onHideAds: () => ProSheet.show(context)),
        ],
      ],
    );
  }
}

class _ProjectList extends ConsumerWidget {
  final LibraryView view;
  const _ProjectList({required this.view});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ui = ref.watch(libraryUiProvider);
    final now = ref.watch(clockProvider)();
    final actions = _LibraryActions(context, ref, view);

    // The fresh copy after a duplicate goes to the top, highlighted (1.7).
    final items = [
      ...view.items.where((i) => i.summary.id == ui.highlightedId),
      ...view.items.where((i) => i.summary.id != ui.highlightedId),
    ];
    final slotsLeft = view.slotsLeft;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 22),
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
          const SizedBox(height: 14),
        ],
        for (final (i, item) in items.indexed) ...[
          ProjectCard(
            item: item,
            now: now,
            frameHeight: i == 0 ? 150 : 120,
            highlighted: item.summary.id == ui.highlightedId,
            onOpen: () => actions.open(item),
            onMore: () => actions.more(item),
            onRename: () => actions.rename(item),
            onDelete: ui.freeingSlot ? () => actions.delete(item) : null,
          ),
          const SizedBox(height: 14),
        ],
        if (slotsLeft != null && slotsLeft > 0 && !ui.freeingSlot) ...[
          SlotCard(reel: view.nextReel, slotsLeft: slotsLeft, onUpgrade: () => ProSheet.show(context)),
          const SizedBox(height: 14),
        ],
        if (view.entitlement.showsAds) ...[
          const SizedBox(height: 14),
          EcAdSlot(onHideAds: () => ProSheet.show(context)),
        ],
      ],
    );
  }
}

/// The library's project actions, each ending in the design's feedback:
/// a dark toast with a ten-second undo for anything that removes or adds a
/// project.
class _LibraryActions {
  final BuildContext context;
  final WidgetRef ref;
  final LibraryView view;

  _LibraryActions(this.context, this.ref, this.view);

  LibraryController get _library => ref.read(libraryControllerProvider);

  void open(LibraryItem item) {
    ref.read(libraryUiProvider.notifier).highlight(null);
    openStoredProject(context, item.summary.id);
  }

  Future<void> more(LibraryItem item) async {
    final action = await ProjectActionsSheet.show(context, item.summary, slotsLeft: view.slotsLeft);
    if (!context.mounted) return;
    switch (action) {
      case ProjectAction.open:
        open(item);
      case ProjectAction.duplicate:
        await duplicate(item);
      case ProjectAction.rename:
        await rename(item);
      case ProjectAction.delete:
        await delete(item);
      case null:
        break;
    }
  }

  // Undo runs after the toast outlives this widget (the list can rebuild
  // into the empty state), so it captures the controller and notifier, which
  // live in providers, rather than going back through this widget's ref.

  Future<void> duplicate(LibraryItem item) async {
    final library = _library;
    final ui = ref.read(libraryUiProvider.notifier);
    final result = await library.duplicate(item.summary.id);
    if (!context.mounted) return;
    switch (result) {
      case Ok(value: final copy):
        final nowFull = !view.entitlement.canAddProject(view.count + 1);
        showEcToast(
          context,
          nowFull ? 'Duplicated · slots now full' : 'Duplicated',
          actionLabel: 'Undo',
          onAction: () {
            ui.highlight(null);
            library.delete(copy.id);
          },
        );
      case Err(:final failure) when isSlotsFull(failure):
        await handleSlotsFull(context);
      case Err(:final failure):
        showEcToast(context, failure.message);
    }
  }

  Future<void> rename(LibraryItem item) async {
    final title = await RenameSheet.show(context, item.summary.title);
    if (title == null || !context.mounted) return;
    final result = await _library.rename(item.summary.id, title);
    if (result case Err(:final failure) when context.mounted) showEcToast(context, failure.message);
  }

  Future<void> delete(LibraryItem item) async {
    final library = _library;
    final confirmed = await DeleteProjectSheet.confirm(context, item.summary);
    if (!confirmed || !context.mounted) return;
    final result = await library.delete(item.summary.id);
    if (!context.mounted) return;
    switch (result) {
      case Ok(value: final deleted):
        ref.read(libraryUiProvider.notifier).setFreeingSlot(false);
        showEcToast(context, 'Deleted “${deleted.title}”', actionLabel: 'Undo', onAction: () => library.restore(deleted));
      case Err(:final failure):
        showEcToast(context, failure.message);
    }
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center, style: context.type.body),
            const SizedBox(height: 16),
            EcButton.secondary(label: 'Try again', size: EcButtonSize.medium, onPressed: onRetry),
          ],
        ),
      ),
    );
  }
}
