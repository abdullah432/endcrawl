import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/result.dart';
import '../../../core/theme/tokens.dart';
import '../../../domain/models/project.dart';
import '../../appendix/screens/appendix_screen.dart';
import '../../editor/screens/editor_screen.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../project/controllers/project_controller.dart';
import '../../templates/screens/templates_screen.dart';
import '../controllers/library_controller.dart';
import '../widgets/project_card.dart';
import '../widgets/resume_card.dart';

/// The app's home: everything already saved on this device, with the
/// last-open project offered back at the top.
class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  bool _resumeDismissed = false;

  Future<void> _open(String id) async {
    final result = await ref.read(projectControllerProvider.notifier).openProject(id);
    if (!mounted) return;

    switch (result) {
      case Ok():
        ref.read(playbackControllerProvider.notifier).resetToHead();
        // Flags the document as open before the editor appears, so a kill
        // while editing leaves something to recover.
        await ref.read(projectControllerProvider.notifier).markOpened();
        if (!mounted) return;
        await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const EditorScreen()));
        if (!mounted) return;
        ref.invalidate(projectSummariesProvider);
      case Err(:final failure):
        _showMessage(failure.message);
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _handleAction(ProjectSummary summary, ProjectCardAction action) async {
    final library = ref.read(libraryControllerProvider);

    switch (action) {
      case ProjectCardAction.rename:
        final title = await _promptForTitle(summary.title);
        if (title == null) return;
        final result = await library.rename(summary.id, title);
        if (result case Err(:final failure)) _showMessage(failure.message);
      case ProjectCardAction.duplicate:
        final result = await library.duplicate(summary.id);
        if (result case Err(:final failure)) _showMessage(failure.message);
      case ProjectCardAction.delete:
        final confirmed = await _confirmDelete(summary.title);
        if (confirmed != true) return;
        final result = await library.delete(summary.id);
        if (result case Err(:final failure)) _showMessage(failure.message);
    }
  }

  Future<String?> _promptForTitle(String current) {
    final controller = TextEditingController(text: current);
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EcColors.surfaceOverlay,
        title: const Text('Rename project', style: TextStyle(fontSize: 16)),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(controller.text), child: const Text('Rename')),
        ],
      ),
    );
  }

  Future<bool?> _confirmDelete(String title) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: EcColors.surfaceOverlay,
        title: const Text('Delete project?', style: TextStyle(fontSize: 16)),
        content: Text('"$title" will be permanently deleted from this device.',
            style: const TextStyle(fontSize: 13, color: EcColors.textSecondary)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete', style: TextStyle(color: EcColors.warn)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final summaries = ref.watch(projectSummariesProvider);
    final resume = ref.watch(resumeCandidateProvider).value;

    return Scaffold(
      backgroundColor: EcColors.surfaceCanvas,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s4, EcSpace.s3, 0),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'ENDCRAWL',
                      style: TextStyle(
                        fontFamily: EcFonts.archivoNarrow,
                        fontWeight: FontWeight.w700,
                        fontSize: 18,
                        letterSpacing: 4.5,
                        color: EcColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Design system',
                    icon: const Icon(Icons.palette_outlined, color: EcColors.textTertiary, size: 20),
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AppendixScreen()),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: switch (summaries) {
                AsyncLoading() => const Center(
                    child: CircularProgressIndicator(color: EcColors.accentPrimary, strokeWidth: 2),
                  ),
                AsyncError(:final error) => _ErrorState(
                    message: error is AppFailure ? error.message : 'Could not open your projects.',
                    onRetry: () => ref.invalidate(projectSummariesProvider),
                  ),
                AsyncValue(:final value) => _List(
                    summaries: value ?? const [],
                    resume: _resumeDismissed ? null : resume,
                    onOpen: _open,
                    onAction: _handleAction,
                    onDismissResume: () => setState(() => _resumeDismissed = true),
                  ),
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: EcColors.accentPrimary,
        foregroundColor: EcColors.accentInk,
        onPressed: () async {
          await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const TemplatesScreen()));
          if (!context.mounted) return;
          ref.invalidate(projectSummariesProvider);
        },
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New project', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}

class _List extends StatelessWidget {
  final List<ProjectSummary> summaries;
  final ProjectSummary? resume;
  final ValueChanged<String> onOpen;
  final void Function(ProjectSummary, ProjectCardAction) onAction;
  final VoidCallback onDismissResume;

  const _List({
    required this.summaries,
    required this.resume,
    required this.onOpen,
    required this.onAction,
    required this.onDismissResume,
  });

  @override
  Widget build(BuildContext context) {
    if (summaries.isEmpty) return const _EmptyState();

    return ListView(
      padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s5, EcSpace.s4, 96),
      children: [
        if (resume != null)
          ResumeCard(
            summary: resume!,
            onOpen: () => onOpen(resume!.id),
            onDismiss: onDismissResume,
          ),
        const Padding(
          padding: EdgeInsets.only(bottom: EcSpace.s3),
          child: Text('YOUR PROJECTS', style: TextStyle(fontSize: 11, letterSpacing: 2.2, color: EcColors.textTertiary)),
        ),
        for (final summary in summaries)
          Padding(
            padding: const EdgeInsets.only(bottom: EcSpace.s3),
            child: ProjectCard(
              summary: summary,
              onOpen: () => onOpen(summary.id),
              onAction: (action) => onAction(summary, action),
            ),
          ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(EcSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'No projects yet',
              style: TextStyle(
                fontFamily: EcFonts.archivo,
                fontWeight: FontWeight.w600,
                fontSize: 22,
                color: EcColors.textPrimary,
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Start one from a template — the card order is already right.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13, color: EcColors.textSecondary, height: 1.4),
            ),
          ],
        ),
      ),
    );
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
        padding: const EdgeInsets.all(EcSpace.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: EcColors.textSecondary, height: 1.4)),
            const SizedBox(height: EcSpace.s4),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: EcColors.textPrimary,
                side: const BorderSide(color: EcColors.borderStrong),
              ),
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}
