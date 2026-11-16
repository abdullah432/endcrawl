import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../controllers/export_controller.dart';
import '../models/export_models.dart';

/// The same persistent delivery feedback on phones and tablets.
class GallerySaveStatus extends ConsumerWidget {
  final ExportRun run;
  const GallerySaveStatus({super.key, required this.run});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = defaultTargetPlatform == TargetPlatform.android
        ? 'Gallery'
        : 'Photos';
    if (run.gallerySave == GallerySave.notApplicable) {
      return const SizedBox.shrink();
    }
    final title = switch (run.gallerySave) {
      GallerySave.saving => 'Saving to $library…',
      GallerySave.saved => 'Saved to $library',
      _ => 'Video ready · not saved to $library',
    };
    final detail = switch (run.gallerySave) {
      GallerySave.saving =>
        'Allow access if asked. Keep LastReel open while saving.',
      GallerySave.saved =>
        'Find your video in $library. You can now add it to your movie.',
      _ => run.galleryMessage ?? 'Try again or share the video below.',
    };
    return Semantics(
      liveRegion: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 6),
            Text(detail),
            if (run.gallerySave == GallerySave.saving) ...[
              const SizedBox(height: 10),
              const LinearProgressIndicator(),
            ],
            if (run.gallerySave == GallerySave.failed)
              TextButton(
                onPressed: () => ref
                    .read(exportControllerProvider.notifier)
                    .retryGallerySave(),
                child: const Text('Retry saving'),
              ),
          ],
        ),
      ),
    );
  }
}
