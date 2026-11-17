import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/theme_context.dart';
import '../controllers/export_controller.dart';
import '../models/export_models.dart';

/// 6.4 — the automatic save, shown as a status row rather than a button:
/// "Saving to Photos…" → "Saved to Photos" ("Gallery" on Android), or
/// "Not saved" with a compact Retry and the reason the OS gave. Share stays
/// available beside it in every state, since it works from the local file.
class GallerySaveStatus extends ConsumerWidget {
  final ExportRun run;

  /// Drawn as its own card — the tablet's renders panel. On the phone it
  /// is the first row of the destinations group.
  final bool boxed;

  const GallerySaveStatus({super.key, required this.run, this.boxed = false});

  /// Where the video lands: Photos on Apple devices, Gallery on Android.
  static String get library => defaultTargetPlatform == TargetPlatform.android ? 'Gallery' : 'Photos';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (run.gallerySave == GallerySave.notApplicable) {
      return const SizedBox.shrink();
    }
    final p = context.palette;
    final t = context.type;
    final library = GallerySaveStatus.library;
    final state = run.gallerySave;
    final title = switch (state) {
      GallerySave.saving => 'Saving to $library…',
      GallerySave.saved => 'Saved to $library',
      _ => 'Not saved to $library',
    };
    final detail = switch (state) {
      GallerySave.saving => 'Keep LastReel open for a moment.',
      GallerySave.saved => 'Find it in your $library library.',
      _ => run.galleryMessage ?? 'Try again, or share the video below.',
    };
    final leading = switch (state) {
      GallerySave.saving => SizedBox.square(
        dimension: 20,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: p.accentSolid, backgroundColor: p.tint),
      ),
      GallerySave.saved => _Badge(fill: p.okWash, child: Icon(Icons.check_rounded, size: 16, color: p.ok)),
      _ => _Badge(fill: p.warnWash, child: Icon(Icons.priority_high_rounded, size: 16, color: p.warn)),
    };

    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 62),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 9, state == GallerySave.failed ? 8 : 16, 9),
        child: Row(
          children: [
            SizedBox.square(dimension: 28, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(title, style: t.titleS.copyWith(fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(detail, style: t.caption.copyWith(fontSize: 12)),
                ],
              ),
            ),
            if (state == GallerySave.failed) ...[
              const SizedBox(width: 8),
              _RetryButton(
                library: library,
                onTap: () => ref.read(exportControllerProvider.notifier).retryGallerySave(),
              ),
            ],
          ],
        ),
      ),
    );

    final content = Semantics(liveRegion: true, container: true, child: row);
    if (!boxed) return content;
    return Container(
      decoration: BoxDecoration(
        color: p.surface,
        border: Border.all(color: p.line),
        borderRadius: BorderRadius.circular(20),
      ),
      child: content,
    );
  }
}

class _Badge extends StatelessWidget {
  final Color fill;
  final Widget child;
  const _Badge({required this.fill, required this.child});

  @override
  Widget build(BuildContext context) => Container(
    width: 28,
    height: 28,
    decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
    child: Center(child: child),
  );
}

/// A 32 px outlined pill inside a 44 px tap area.
class _RetryButton extends StatelessWidget {
  final String library;
  final VoidCallback onTap;
  const _RetryButton({required this.library, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Semantics(
      button: true,
      label: 'Retry saving to $library',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Center(
              widthFactor: 1,
              child: Container(
                height: 32,
                padding: const EdgeInsets.symmetric(horizontal: 14),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: p.accentLine),
                ),
                child: Text('Retry', style: t.buttonSmall.copyWith(fontSize: 13, color: p.accent)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
