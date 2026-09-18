import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/repositories/template_repository.dart';

class TemplateCard extends StatelessWidget {
  final ProjectTemplate template;
  final VoidCallback onTap;

  const TemplateCard({super.key, required this.template, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final isTall = template.id == 'youtube';
    return Material(
      color: EcColors.surfaceRaised,
      borderRadius: BorderRadius.circular(EcRadius.lg),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(EcRadius.lg),
        child: Container(
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.all(EcSpace.s4),
          decoration: BoxDecoration(
            border: Border.all(color: EcColors.borderHairline),
            borderRadius: BorderRadius.circular(EcRadius.lg),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Colors.black,
                  border: Border.all(color: EcColors.borderHairline),
                  borderRadius: BorderRadius.circular(EcRadius.md),
                ),
                child: Container(
                  width: isTall ? 14 : 28,
                  height: isTall ? 26 : 16,
                  decoration: BoxDecoration(
                    border: Border.all(color: EcColors.accentDim, width: 1.5),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(width: EcSpace.s4),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(template.name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, letterSpacing: -0.1, color: EcColors.textPrimary)),
                    const SizedBox(height: 3),
                    Text(template.description, style: const TextStyle(fontSize: 12, color: EcColors.textSecondary, height: 1.35)),
                    const SizedBox(height: 6),
                    Text(template.meta, style: const TextStyle(fontFamily: EcFonts.mono, fontSize: 10, color: EcColors.textTertiary)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
