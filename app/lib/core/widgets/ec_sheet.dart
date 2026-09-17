import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Shared chrome for every bottom sheet in the editor: drag handle, title,
/// close button, scrollable body. Port of the prototype's shared sheet
/// shell (`sheetOpen` / `sheetTitle` / `sheetH`).
class EcSheet extends StatelessWidget {
  final String title;
  final Widget child;
  final double maxHeightFraction;

  const EcSheet({super.key, required this.title, required this.child, this.maxHeightFraction = 0.86});

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.sizeOf(context).height * maxHeightFraction;
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: EcColors.surfaceOverlay,
        borderRadius: BorderRadius.vertical(top: Radius.circular(EcRadius.xl)),
        border: Border(top: BorderSide(color: EcColors.borderStrong)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: EcColors.borderStrong, borderRadius: BorderRadius.circular(EcRadius.full)),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(EcSpace.s4, EcSpace.s3, EcSpace.s4, EcSpace.s2),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.01, color: EcColors.textPrimary),
                    ),
                  ),
                  InkWell(
                    onTap: () => Navigator.of(context).maybePop(),
                    borderRadius: BorderRadius.circular(EcRadius.full),
                    child: Container(
                      width: 30,
                      height: 30,
                      decoration: const BoxDecoration(color: EcColors.surfaceHi, shape: BoxShape.circle),
                      alignment: Alignment.center,
                      child: const Icon(Icons.close, size: 15, color: EcColors.textSecondary),
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(EcSpace.s4, 0, EcSpace.s4, EcSpace.s4),
                child: child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A small caps section label used throughout the sheets
/// ("Delimiter · detected candidates", "Codec", …).
class EcSectionLabel extends StatelessWidget {
  final String text;
  const EcSectionLabel(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: EcSpace.s2),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(fontSize: 9.5, letterSpacing: 1.33, color: EcColors.textTertiary),
      ),
    );
  }
}
