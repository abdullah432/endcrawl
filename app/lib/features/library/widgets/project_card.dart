import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/utils/relative_time.dart';
import '../../../domain/engine/roll_engine.dart';
import '../../../domain/models/canvas_format.dart';
import '../../../domain/models/project.dart';
import '../../../domain/models/project_settings.dart';

enum ProjectCardAction { rename, duplicate, delete }

class ProjectCard extends StatelessWidget {
  final ProjectSummary summary;
  final bool recovered;
  final VoidCallback onOpen;
  final ValueChanged<ProjectCardAction> onAction;

  const ProjectCard({
    super.key,
    required this.summary,
    required this.onOpen,
    required this.onAction,
    this.recovered = false,
  });

  @override
  Widget build(BuildContext context) {
    final settings = summary.settings;
    final format = settings.formatId == 'custom'
        ? '${settings.customW}×${settings.customH}'
        : CanvasFormat.byId(settings.formatId).label;

    // In duration mode the target runtime is the user's own input, so it is
    // exact. In speed mode the runtime falls out of the measured content
    // height, which the library has not laid out — so it stays honest and
    // shows nothing rather than a guess.
    final runtime = settings.mode == TimingMode.duration
        ? formatTimecode(settings.durationFrames.toDouble(), settings.fps)
        : null;

    return Material(
      color: EcColors.surfaceRaised,
      borderRadius: BorderRadius.circular(EcRadius.lg),
      child: InkWell(
        onTap: onOpen,
        borderRadius: BorderRadius.circular(EcRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(EcSpace.s4),
          decoration: BoxDecoration(
            border: Border.all(color: EcColors.borderHairline),
            borderRadius: BorderRadius.circular(EcRadius.lg),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            summary.title,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: EcColors.textPrimary),
                          ),
                        ),
                        if (recovered)
                          Container(
                            margin: const EdgeInsets.only(left: 6),
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                            decoration: BoxDecoration(
                              border: Border.all(color: EcColors.accentDim),
                              borderRadius: BorderRadius.circular(EcRadius.sm),
                            ),
                            child: const Text('RECOVERED', style: TextStyle(fontSize: 9, letterSpacing: 1, color: EcColors.accentPrimary)),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$format · ${settings.fps} fps${runtime == null ? '' : ' · $runtime'}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10.5, color: EcColors.textTertiary),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${summary.blockCount} blocks · ${formatRelativeTime(summary.updatedAt)}',
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 12, color: EcColors.textSecondary),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<ProjectCardAction>(
                onSelected: onAction,
                color: EcColors.surfaceOverlay,
                icon: const Icon(Icons.more_vert, size: 18, color: EcColors.textTertiary),
                itemBuilder: (context) => const [
                  PopupMenuItem(value: ProjectCardAction.rename, child: Text('Rename')),
                  PopupMenuItem(value: ProjectCardAction.duplicate, child: Text('Duplicate')),
                  PopupMenuItem(value: ProjectCardAction.delete, child: Text('Delete', style: TextStyle(color: EcColors.warn))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
