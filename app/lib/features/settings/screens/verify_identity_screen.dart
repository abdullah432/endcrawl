import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_headline.dart';
import '../../../core/widgets/ec_scaffold.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../domain/models/app_user.dart';
import '../../auth/widgets/google_mark.dart';
import '../controllers/account_controller.dart';

/// 7.6b — between "Delete account permanently" and the Google (or Apple)
/// sheet, so the sign-in that deletion requires is explained rather than
/// sprung on the person. Verifying runs the deletion straight on; nothing
/// is deleted unless it succeeds.
///
/// Pops with `true` when the person chooses to keep the account, so 7.6
/// closes too and they land back on Settings.
class VerifyIdentityScreen extends ConsumerStatefulWidget {
  final SignInMethod method;

  const VerifyIdentityScreen({super.key, required this.method});

  static Future<bool> open(BuildContext context, SignInMethod method) async {
    final kept = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => VerifyIdentityScreen(method: method)),
    );
    return kept ?? false;
  }

  @override
  ConsumerState<VerifyIdentityScreen> createState() => _VerifyIdentityScreenState();
}

enum _Phase { idle, verifying, deleting }

class _VerifyIdentityScreenState extends ConsumerState<VerifyIdentityScreen> {
  _Phase _phase = _Phase.idle;
  String? _error;
  bool _cancelled = false;

  bool get _busy => _phase != _Phase.idle;
  String get _provider => widget.method == SignInMethod.apple ? 'Apple' : 'Google';

  Future<void> _verifyAndDelete() async {
    setState(() {
      _phase = _Phase.verifying;
      _error = null;
      _cancelled = false;
    });
    final account = ref.read(accountControllerProvider);
    if (await account.verifyIdentity() case Err(:final failure)) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _cancelled = isCancellation(failure);
        _error = _cancelled ? null : failure.message;
      });
      return;
    }
    if (!mounted) return;
    setState(() => _phase = _Phase.deleting);
    // On success the gate replaces this whole stack with 7.6c.
    if (await account.deleteVerified() case Err(:final failure)) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _error = failure.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final email = ref.watch(authStateProvider).value?.email;
    final retry = _error != null || _cancelled;

    final verify = widget.method == SignInMethod.apple
        ? EcButton(
            label: retry ? 'Try again with Apple' : 'Continue with Apple',
            variant: EcButtonVariant.black,
            busy: _busy,
            leading: const Icon(Icons.apple, size: 20, color: Colors.white),
            onPressed: _busy ? null : _verifyAndDelete,
          )
        : EcButton.secondary(
            label: retry ? 'Try again with Google' : 'Continue with Google',
            busy: _busy,
            leading: const GoogleMark(),
            onPressed: _busy ? null : _verifyAndDelete,
          );

    return PopScope(
      // Mid-verification the sheet is up and the deletion may be running;
      // leaving now would only hide what happens next.
      canPop: !_busy,
      child: EcScaffold(
        maxContentWidth: 520,
        topBar: const EcTopBar(),
        padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: p.accentWash,
                  shape: BoxShape.circle,
                  border: Border.all(color: p.accentLine),
                ),
                child: Icon(Icons.verified_user_outlined, size: 30, color: p.accent),
              ),
            ),
            const SizedBox(height: 22),
            Center(child: EcEyebrow('Delete account', color: p.warn)),
            const SizedBox(height: 10),
            EcHeadline('Verify', emphasis: 'your identity.', textAlign: TextAlign.center, style: t.displayM),
            const SizedBox(height: 14),
            Text.rich(
              TextSpan(
                style: t.body,
                children: [
                  const TextSpan(
                    text: 'For your security, we need to verify that it’s really you before permanently '
                        'deleting your account. Please sign in again with ',
                  ),
                  if (email != null) ...[
                    TextSpan(text: 'the $_provider account '),
                    TextSpan(
                      text: email,
                      style: TextStyle(fontWeight: FontWeight.w600, color: p.ink),
                    ),
                  ] else
                    TextSpan(text: 'your $_provider account'),
                  const TextSpan(text: ' to continue.'),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            EcNotice(
              tone: EcTone.neutral,
              icon: Icons.info_outline_rounded,
              title: 'No need to start over',
              body: 'Once your identity is verified, your account deletion will be completed automatically. '
                  'You won’t need to repeat the deletion process.',
            ),
            if (_cancelled) ...[
              const SizedBox(height: 12),
              EcNotice(
                tone: EcTone.neutral,
                title: '$_provider sign-in was cancelled.',
                body: 'Your account hasn’t changed. Nothing was deleted.',
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              EcNotice(
                tone: EcTone.warn,
                title: 'We couldn’t verify it’s you.',
                body: _error,
              ),
            ],
            const Spacer(),
            const SizedBox(height: 20),
            if (_busy) ...[
              Text(
                _phase == _Phase.verifying ? 'Waiting for $_provider…' : 'Deleting your account…',
                textAlign: TextAlign.center,
                style: t.bodyS.copyWith(color: p.muted),
              ),
              const SizedBox(height: 10),
            ],
            verify,
            const SizedBox(height: 6),
            EcButton.text(
              label: 'Cancel and keep my account',
              expand: true,
              onPressed: _busy ? null : () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      ),
    );
  }
}
