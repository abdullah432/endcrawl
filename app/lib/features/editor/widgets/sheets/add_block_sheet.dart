import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/tokens.dart';
import '../../../../core/widgets/ec_sheet.dart';
import '../../../project/controllers/project_controller.dart';
import '../../../../domain/models/credit_block.dart';
import '../../../../data/repositories/template_repository.dart';

const _kAddTypes = [
  ('title', 'TTL', 'Title card', 'Studio banner, film title, "a film by".'),
  ('cast', 'CAST', 'Two-column cast', 'Role and actor across a fixed centre gutter.'),
  ('dept', 'DEPT', 'Department', 'DIRECTED BY, EDITED BY, and the rest.'),
  ('song', 'SONG', 'Soundtrack', 'Song, artist, courtesy-of — three conventional lines.'),
  ('thanks', 'THX', 'Special thanks', 'Flowing multi-column name list that balances itself.'),
  ('logos', 'LOGO', 'Logo row', 'Financiers and post houses, optically spaced.'),
  ('hold', 'HOLD', 'Hold card', 'Stops the roll. Fade in, hold, fade out.'),
  ('spacer', 'SPC', 'Spacer', 'Explicit gap, in seconds.'),
];

class AddBlockSheet extends ConsumerWidget {
  const AddBlockSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const repo = TemplateRepository();
    final controller = ref.read(projectControllerProvider.notifier);

    CreditBlock make(String id) => switch (id) {
          'title' => repo.mkTitle(),
          'cast' => repo.mkCast(),
          'dept' => repo.mkDept('DEPARTMENT', const ['Name']),
          'song' => repo.mkSong(),
          'thanks' => repo.mkThanks(),
          'logos' => repo.mkLogos(),
          'hold' => repo.mkHold(3, const ['HOLD CARD']),
          _ => repo.mkSpacer(),
        };

    return EcSheet(
      title: 'Add block',
      child: Column(
        children: [
          for (final t in _kAddTypes)
            Padding(
              padding: const EdgeInsets.only(bottom: EcSpace.s2),
              child: Material(
                color: EcColors.surfaceRaised,
                borderRadius: BorderRadius.circular(EcRadius.md),
                child: InkWell(
                  borderRadius: BorderRadius.circular(EcRadius.md),
                  onTap: () {
                    controller.addBlock(make(t.$1));
                    Navigator.of(context).maybePop();
                  },
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 58),
                    padding: const EdgeInsets.all(EcSpace.s3),
                    decoration: BoxDecoration(border: Border.all(color: EcColors.borderHairline), borderRadius: BorderRadius.circular(EcRadius.md)),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(color: EcColors.surfaceHi, borderRadius: BorderRadius.circular(EcRadius.sm)),
                          alignment: Alignment.center,
                          child: Text(t.$2, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 9.5, color: EcColors.textSecondary)),
                        ),
                        const SizedBox(width: EcSpace.s3),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t.$3, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
                              Text(t.$4, style: const TextStyle(fontSize: 11.5, color: EcColors.textTertiary, height: 1.3)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          Material(
            color: EcColors.accentWash,
            borderRadius: BorderRadius.circular(EcRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(EcRadius.md),
              onTap: () {
                controller.addDepartmentSet();
                Navigator.of(context).maybePop();
              },
              child: Container(
                constraints: const BoxConstraints(minHeight: 58),
                padding: const EdgeInsets.all(EcSpace.s3),
                decoration: BoxDecoration(border: Border.all(color: EcColors.accentDim), borderRadius: BorderRadius.circular(EcRadius.md)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    Text('Standard department order', style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: EcColors.accentPrimary)),
                    SizedBox(height: 2),
                    Text('Inserts the conventional sequence, in order, ready to fill.', style: TextStyle(fontSize: 11.5, color: EcColors.textSecondary, height: 1.3)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
