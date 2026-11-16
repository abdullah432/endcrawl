import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bootstrap.dart';
import '../../../core/theme/theme_context.dart';
import '../controllers/web_billing.dart';
import '../../access/screens/web_access_screen.dart';
import 'web_pro_welcome.dart';
import 'web_payment_issue.dart';

/// A redirect only triggers verification. It never grants access or trusts URL identity.
class WebCheckoutReturn extends ConsumerStatefulWidget {
  final Widget child;
  const WebCheckoutReturn({super.key, required this.child});
  @override
  ConsumerState<WebCheckoutReturn> createState() => _WebCheckoutReturnState();
}

class _WebCheckoutReturnState extends ConsumerState<WebCheckoutReturn> {
  Timer? _timer;
  int _attempt = 0;
  bool _checking = false;
  bool _dismissed = false;
  bool _confirmed = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    if (ref.read(webCheckoutReturnedProvider)) {
      _message = 'Confirming your subscription…';
      WidgetsBinding.instance.addPostFrameCallback((_) => _check());
    } else if (ref.read(webBillingEnabledProvider) &&
        Uri.base.queryParameters['subscribe'] == '1') {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) WebAccessScreen.open(context);
      });
    }
  }

  Future<void> _check() async {
    if (!mounted || _checking || _dismissed) return;
    final uid = ref.read(currentUidProvider);
    if (uid == null) return;
    _timer?.cancel();
    setState(() {
      _checking = true;
      _message = 'Confirming your subscription…';
    });
    final result = await ref.read(entitlementRepositoryProvider).restore();
    if (!mounted || ref.read(currentUidProvider) != uid || _dismissed) return;
    final pro = result.valueOrNull?.isPro ?? false;
    setState(() {
      _checking = false;
      _confirmed = pro;
      _message = pro
          ? 'Pro is active. Your workspace is ready.'
          : 'Your subscription is not confirmed yet. Check again in a moment, or contact support if you have a receipt.';
    });
    if (!pro && ++_attempt < 4) {
      _timer = Timer(Duration(seconds: _attempt * 2), _check);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUidProvider, (_, _) {
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _dismissed = true;
          _confirmed = false;
          _message = null;
        });
      }
    });
    if (_confirmed && !_dismissed) {
      return WebProWelcome(
        onOpenProjects: () => setState(() => _dismissed = true),
      );
    }
    return Column(
      children: [
        if (ref.watch(entitlementProvider).value?.billingIssue ?? false)
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: WebPaymentIssue(),
          ),
        if (_message != null && !_dismissed)
          Material(
            color: context.palette.surface,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Row(
                  children: [
                    if (_checking)
                      const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_message!, style: context.type.bodyS),
                      ),
                    ),
                    TextButton(
                      onPressed: _checking ? null : _check,
                      child: const Text('Check access'),
                    ),
                    IconButton(
                      tooltip: 'Dismiss',
                      onPressed: () {
                        _timer?.cancel();
                        setState(() => _dismissed = true);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
            ),
          ),
        Expanded(child: widget.child),
      ],
    );
  }
}
