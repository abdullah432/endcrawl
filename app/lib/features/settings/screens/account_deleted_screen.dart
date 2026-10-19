import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../controllers/account_controller.dart';

/// 7.6c — shown by the gate once the account is gone and signed out; "Done"
/// clears it, and the gate falls through to the welcome screen.
class AccountDeletedScreen extends ConsumerWidget {
  const AccountDeletedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final t = context.type;
    void done() => ref.read(accountDeletedProvider.notifier).set(false);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) => didPop ? null : done(),
      child: EcScaffold(
        maxContentWidth: 520,
        padding: const EdgeInsets.fromLTRB(24, 40, 24, 24),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Spacer(),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(color: p.okWash, shape: BoxShape.circle),
                child: Icon(Icons.check_rounded, size: 32, color: p.ok),
              ),
            ),
            const SizedBox(height: 22),
            Center(child: EcEyebrow('Account deleted', color: p.ok)),
            const SizedBox(height: 10),
            EcHeadline('Your account is', emphasis: 'gone.', textAlign: TextAlign.center, style: t.displayM),
            const SizedBox(height: 14),
            Text(
              'Your projects, profile and sign-in methods have been deleted, and you’ve been signed out '
              'on this device. Backups are purged within 30 days.',
              textAlign: TextAlign.center,
              style: t.body,
            ),
            const Spacer(),
            const SizedBox(height: 24),
            EcButton(label: 'Done', onPressed: done),
          ],
        ),
      ),
    );
  }
}
