import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../bootstrap.dart';
import '../../../core/config/app_links.dart';
import '../../../core/result.dart';
import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_button.dart';
import '../../../core/widgets/ec_sheet.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/entitlement.dart';

/// Store handoff isolated from the native paywall and future browser checkout.
class MobileSubscriptionCard extends ConsumerStatefulWidget {
  final VoidCallback? onVerified;
  const MobileSubscriptionCard({super.key, this.onVerified});
  static Future<void> show(BuildContext context) => showEcSheet<void>(
    context,
    builder: (context) => EcSheet(
      title: 'Pro on every screen',
      child: MobileSubscriptionCard(onVerified: () => closeEcSheet(context)),
    ),
  );
  @override
  ConsumerState<MobileSubscriptionCard> createState() =>
      _MobileSubscriptionCardState();
}

class _MobileSubscriptionCardState
    extends ConsumerState<MobileSubscriptionCard> {
  bool _checking = false;
  String? _message;
  Future<void> _check() async {
    if (_checking) return;
    final uid = ref.read(currentUidProvider);
    setState(() {
      _checking = true;
      _message = null;
    });
    final result = await ref.read(entitlementRepositoryProvider).restore();
    if (!mounted || ref.read(currentUidProvider) != uid) return;
    setState(() {
      _checking = false;
      _message = switch (result) {
        Ok<Entitlement>(:final value) =>
          value.isPro
              ? 'Pro is active. You’re ready to work.'
              : 'No active Pro subscription found yet. Use the same account in the mobile app, then check again.',
        Err(:final failure) => failure.message,
      };
    });
    if (result case Ok<Entitlement>(:final value) when value.isPro) {
      widget.onVerified?.call();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authStateProvider).value;
    final plan = ref.watch(entitlementProvider).value;
    final links = ref.read(externalLinksProvider);
    final p = context.palette;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Your workspace, everywhere.', style: context.type.displayM),
        const SizedBox(height: 8),
        Text(
          'The web workspace is included with Pro. Subscribe in the mobile app, then return here to edit and export on a larger screen.',
          style: context.type.bodyS,
        ),
        const SizedBox(height: 12),
        Text(
          'Unlimited projects · browser MP4 and PNG exports · up to 4K on supported devices',
          style: context.type.bodyS.copyWith(color: p.accent),
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in with the same account${user?.email == null ? '.' : ': ${user!.email}'}',
          style: context.type.bodyS,
        ),
        const SizedBox(height: 16),
        if (MediaQuery.sizeOf(context).width >= 1280)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Semantics(
                label: 'Scan to download LastReel from Google Play',
                child: QrImageView(
                  data: AppLinks.androidDownload.toString(),
                  size: 112,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Scan with your Android phone to open the app’s Google Play page.',
                  style: context.type.bodyS,
                ),
              ),
            ],
          ),
        EcButton(
          label: 'Get it on Google Play',
          onPressed: () => links.openUrl(AppLinks.androidDownload),
        ),
        const SizedBox(height: 8),
        if (AppLinks.iosDownload case final url?)
          EcButton.secondary(
            label: 'Download on the App Store',
            onPressed: () => links.openUrl(url),
          )
        else
          Text(
            'iOS · Coming soon',
            textAlign: TextAlign.center,
            style: context.type.caption,
          ),
        if (plan?.managementUrl case final url?)
          TextButton(
            onPressed: () => links.openUrl(url),
            child: const Text('Manage mobile subscription'),
          ),
        const SizedBox(height: 12),
        EcButton.secondary(
          label: _checking
              ? 'Checking access…'
              : 'I’ve subscribed — check access',
          busy: _checking,
          onPressed: _checking ? null : _check,
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: EcNotice(tone: EcTone.neutral, title: _message!),
          ),
      ],
    );
  }
}
