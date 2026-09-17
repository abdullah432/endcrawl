import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/relative_time.dart';
import '../../../domain/models/project.dart';

/// Offers the last-open project back to the user.
///
/// When that project is still flagged as left open, the app was killed with
/// it open, and this is the crash recovery promised in §10 of the brief —
/// driven by what is actually on disk, not a hardcoded flag.
class ResumeCard extends StatelessWidget {
  final ProjectSummary summary;
  final VoidCallback onOpen;
  final VoidCallback onDismiss;

  const ResumeCard({
    super.key,
    required this.summary,
    required this.onOpen,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final recovered = summary.wasLeftOpen;

    return Container(
      margin: const EdgeInsets.only(bottom: EcSpace.s4),
      padding: const EdgeInsets.all(EcSpace.s4),
      decoration: BoxDecoration(
        color: EcColors.accentWash,
        border: Border.all(color: EcColors.accentDim),
        borderRadius: BorderRadius.circular(EcRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recovered ? 'RECOVERED AFTER CRASH' : 'CONTINUE WHERE YOU LEFT OFF',
            style: const TextStyle(fontSize: 11, letterSpacing: 1.5, color: EcColors.accentPrimary),
          ),
          const SizedBox(height: 6),
          Text(
            summary.title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: EcColors.textPrimary),
          ),
          const SizedBox(height: 2),
          Text(
            '${summary.blockCount} blocks · autosaved ${formatRelativeTime(summary.updatedAt)}',
            style: const TextStyle(fontSize: 12, color: EcColors.textSecondary),
          ),
          const SizedBox(height: EcSpace.s3),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: onOpen,
                  style: FilledButton.styleFrom(
                    backgroundColor: EcColors.accentPrimary,
                    foregroundColor: EcColors.accentInk,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
                    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                  child: Text(recovered ? 'Open recovered' : 'Continue'),
                ),
              ),
              const SizedBox(width: EcSpace.s2),
              OutlinedButton(
                onPressed: onDismiss,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EcColors.textSecondary,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: EcColors.borderStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
                ),
                child: const Text('Dismiss', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
