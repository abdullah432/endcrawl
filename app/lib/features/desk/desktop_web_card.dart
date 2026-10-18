import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/theme/theme_context.dart';
import '../../core/theme/tokens.dart';
import '../../core/widgets/ec_button.dart';
import '../../core/widgets/ec_surfaces.dart';
import 'desk_invite.dart';
import '../plan/controllers/release_policy.dart';

/// Settings' permanent way to discover the desk, independent of the
/// occasional library invite. Reuses its Free upgrade/preview and Pro link sheets.
class DesktopWebCard extends ConsumerWidget {
  const DesktopWebCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(iosFreeLaunchProvider)) return const SizedBox.shrink();
    final p = context.palette;
    final t = context.type;
    final pro = ref.watch(entitlementProvider).value?.isPro ?? false;
    final action = EcButton.secondary(
      label: pro ? 'Send the link' : 'Preview',
      size: EcButtonSize.medium,
      expand: false,
      trailing: Icon(
        pro ? Icons.send_outlined : Icons.open_in_new_rounded,
        size: 16,
        color: p.ink,
      ),
      onPressed: () => DeskInvite.showNow(context),
    );
    final status = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          pro ? Icons.check_circle_outline_rounded : Icons.lock_outline_rounded,
          color: pro ? p.ok : p.muted,
          size: 19,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            pro
                ? 'Included with Pro'
                : 'Only with Pro. Take a look before you upgrade.',
            style: t.bodyS.copyWith(color: p.muted),
          ),
        ),
      ],
    );

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.group),
        border: Border.all(color: p.line),
        boxShadow: p.glassShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 60,
                decoration: BoxDecoration(
                  color: p.accentWash,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.desktop_windows_outlined,
                  size: 27,
                  color: p.accent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Semantics(
                          header: true,
                          child: Text(
                            'Desktop & web',
                            style: t.titleS.copyWith(fontSize: 17),
                          ),
                        ),
                        const EcGradientPill('Pro'),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'LastReel also runs in your computer’s browser: blocks, monitor and settings side by side '
                      'on a bigger screen, with the projects you already have.',
                      style: t.body.copyWith(
                        fontSize: 14,
                        height: 1.5,
                        color: p.ink2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Divider(height: 1, color: p.line),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final stacked =
                  constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(1) > 1.2;
              if (stacked) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    status,
                    const SizedBox(height: 12),
                    Align(alignment: Alignment.centerRight, child: action),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: status),
                  const SizedBox(width: 16),
                  action,
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
