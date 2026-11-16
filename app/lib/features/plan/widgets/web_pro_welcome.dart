import 'package:flutter/material.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_scaffold.dart';

/// D4 is shown only after canonical entitlement verification succeeds.
class WebProWelcome extends StatelessWidget {
  final VoidCallback onOpenProjects;
  const WebProWelcome({super.key, required this.onOpenProjects});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    return Scaffold(
      body: EcGround(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              width: 640,
              padding: const EdgeInsets.fromLTRB(48, 44, 48, 36),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: p.line),
                boxShadow: p.glassShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: p.primary,
                      boxShadow: p.primaryShadow,
                    ),
                    child: const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 30,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'SUBSCRIPTION CONFIRMED',
                    style: t.eyebrow.copyWith(fontSize: 10.5, color: p.ok),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'You’re Pro.',
                    style: t.displayXL.copyWith(
                      fontSize: 56,
                      height: 1,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Pro is active. Your workspace is ready.',
                    style: t.body.copyWith(fontSize: 15, height: 1.55),
                  ),
                  const SizedBox(height: 22),
                  LayoutBuilder(
                    builder: (context, bounds) => Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final label in [
                          'Unlimited projects',
                          'PNG alpha exports',
                          'Up to 4K',
                          'Pro on every device',
                        ])
                          SizedBox(
                            width: bounds.maxWidth > 440
                                ? (bounds.maxWidth - 10) / 2
                                : bounds.maxWidth,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12,
                                horizontal: 14,
                              ),
                              decoration: BoxDecoration(
                                color: p.sheet,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.check_rounded,
                                    color: p.ok,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 10),
                                  Flexible(
                                    child: Text(
                                      label,
                                      style: t.body.copyWith(fontSize: 14),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  EcButton(
                    label: 'Open my projects',
                    variant: EcButtonVariant.ink,
                    height: 56,
                    onPressed: onOpenProjects,
                    trailing: const Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 22),
                  Text(
                    'On your phone or tablet? Sign in with this account and Pro is already there.',
                    textAlign: TextAlign.center,
                    style: t.caption.copyWith(fontSize: 12.5, height: 1.5),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
