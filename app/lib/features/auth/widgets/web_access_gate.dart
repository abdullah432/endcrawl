import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bootstrap.dart';
import '../../../core/theme/theme_context.dart';
import '../../export/controllers/export_controller.dart';
import '../../monitor/controllers/playback_controller.dart';
import '../../plan/widgets/mobile_subscription_card.dart';
import '../../plan/controllers/web_access.dart';

/// One boundary for web operations. The Free account sees the real UI beneath it.
class WebAccessGate extends ConsumerWidget {
  final Widget child;
  const WebAccessGate({super.key, required this.child});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(webAccessRequiredProvider) ||
        ref.watch(currentUidProvider) == null) {
      return child;
    }
    final entitlement = ref.watch(entitlementProvider);
    final allowed = ref.watch(webAccessAllowedProvider);
    ref.listen(webAccessAllowedProvider, (previous, next) {
      if (!next) {
        ref.read(playbackControllerProvider.notifier).pause();
        ref.read(exportControllerProvider.notifier).cancel();
      }
    });
    if (allowed) return child;
    return Stack(
      children: [
        ExcludeSemantics(
          child: ExcludeFocus(child: AbsorbPointer(child: child)),
        ),
        Positioned.fill(
          child: ColoredBox(
            color: context.palette.ground.withValues(alpha: .28),
          ),
        ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 16,
          top: 16,
          child: Align(
            alignment: Alignment.bottomCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Material(
                color: context.palette.sheet,
                elevation: 12,
                borderRadius: BorderRadius.circular(24),
                clipBehavior: Clip.antiAlias,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (entitlement.isLoading) ...[
                        const Center(child: CircularProgressIndicator()),
                        const SizedBox(height: 12),
                        Text(
                          'Checking your Pro access…',
                          textAlign: TextAlign.center,
                          style: context.type.bodyS,
                        ),
                      ] else if (entitlement.hasError &&
                          !entitlement.hasValue) ...[
                        Text(
                          'Could not check your subscription',
                          style: context.type.titleM,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your workspace is safe. Retry to verify your access.',
                        ),
                        TextButton(
                          onPressed: () =>
                              ref.read(entitlementRepositoryProvider).restore(),
                          child: const Text('Check again'),
                        ),
                      ] else ...[
                        Text(
                          'Preview · Pro required to work on web',
                          style: context.type.eyebrow.copyWith(
                            color: context.palette.accent,
                          ),
                        ),
                        const SizedBox(height: 12),
                        const MobileSubscriptionCard(),
                      ],
                      TextButton(
                        onPressed: () =>
                            ref.read(authRepositoryProvider).signOut(),
                        child: const Text('Sign out'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
