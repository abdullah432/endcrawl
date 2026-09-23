import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/app_user.dart';
import '../controllers/auth_controller.dart';
import '../widgets/auth_error_banner.dart';
import '../widgets/resend_countdown.dart';

/// 0.5 — the last step for email sign-ups.
///
/// Apple and Google accounts never see it. The screen watches for the link
/// being clicked in Mail — on returning to the app, and every few seconds
/// while it's open — and the gate moves on as soon as the account reads
/// verified, with no "I've clicked it" button to find.
class VerifyEmailScreen extends ConsumerStatefulWidget {
  final AppUser user;

  const VerifyEmailScreen({super.key, required this.user});

  @override
  ConsumerState<VerifyEmailScreen> createState() => _VerifyEmailScreenState();
}

class _VerifyEmailScreenState extends ConsumerState<VerifyEmailScreen> {
  static const _pollEvery = Duration(seconds: 8);

  late final AppLifecycleListener _lifecycle = AppLifecycleListener(onResume: _check);
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
    _poll = Timer.periodic(_pollEvery, (_) => _check());
  }

  void _check() => ref.read(authControllerProvider.notifier).checkVerification();

  @override
  void dispose() {
    _poll?.cancel();
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final form = ref.watch(authControllerProvider);
    final controller = ref.read(authControllerProvider.notifier);
    final p = context.palette;
    final t = context.type;
    final cooling = controller.verificationCooldownLeft() > Duration.zero;

    return EcScaffold(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 30),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                color: p.accentWash,
                shape: BoxShape.circle,
                border: Border.all(color: p.accentLine),
              ),
              child: Icon(Icons.mail_outline_rounded, size: 34, color: p.accent),
            ),
          ),
          const SizedBox(height: 22),
          Center(child: EcEyebrow('One last step', color: p.accent)),
          const SizedBox(height: 14),
          EcHeadline('Check your', emphasis: 'inbox.', textAlign: TextAlign.center, style: t.displayL.copyWith(fontSize: 44)),
          const SizedBox(height: 14),
          Text.rich(
            TextSpan(
              style: t.body,
              children: [
                const TextSpan(text: 'We sent a verification link to '),
                TextSpan(text: widget.user.email ?? 'your email', style: TextStyle(fontWeight: FontWeight.w600, color: p.ink)),
                const TextSpan(text: '. Tap it to finish setting up.'),
              ],
            ),
            textAlign: TextAlign.center,
          ),
          const Spacer(),
          const SizedBox(height: 24),
          AuthErrorBanner(form.formError),
          EcButton(label: 'Open Mail', onPressed: () => ref.read(externalLinksProvider).openMailApp()),
          const SizedBox(height: 10),
          if (cooling)
            SizedBox(
              height: 54,
              child: Center(child: ResendCountdown(remaining: controller.verificationCooldownLeft, onResend: null, label: 'Resend link')),
            )
          else
            EcButton.secondary(
              label: 'Resend link',
              busy: form.isRunning(AuthAction.resendVerification),
              onPressed: form.busy ? null : controller.resendVerification,
            ),
          const SizedBox(height: 4),
          EcButton.text(
            label: 'Use a different email',
            expand: true,
            onPressed: form.busy ? null : controller.useDifferentEmail,
          ),
        ],
      ),
    );
  }
}
