import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// "Recovered after crash" banner — everything renders on-device, so a
/// crash is autosave + a banner, not lost work (§10 of the brief).
class RecoveryBanner extends StatelessWidget {
  final VoidCallback onOpen;
  final VoidCallback onDiscard;

  const RecoveryBanner({super.key, required this.onOpen, required this.onDiscard});

  @override
  Widget build(BuildContext context) {
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
          const Text(
            'RECOVERED AFTER CRASH',
            style: TextStyle(fontSize: 11, letterSpacing: 1.5, color: EcColors.accentPrimary),
          ),
          const SizedBox(height: 6),
          const Text('THE LONG WAY DOWN', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w500, color: EcColors.textPrimary)),
          const SizedBox(height: 2),
          const Text('14 blocks · autosaved 2 min ago', style: TextStyle(fontSize: 12, color: EcColors.textSecondary)),
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
                  child: const Text('Open recovered'),
                ),
              ),
              const SizedBox(width: EcSpace.s2),
              OutlinedButton(
                onPressed: onDiscard,
                style: OutlinedButton.styleFrom(
                  foregroundColor: EcColors.textSecondary,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: EcColors.borderStrong),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(EcRadius.md)),
                ),
                child: const Text('Discard', style: TextStyle(fontSize: 14)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
