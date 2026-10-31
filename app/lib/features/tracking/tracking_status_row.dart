import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../bootstrap.dart';
import '../../core/theme/theme_context.dart';
import '../../core/widgets/ec_settings.dart';
import 'tracking_authorization.dart';

/// A3 — on iOS the old "Personalised ads" switch becomes this row: what App
/// Tracking Transparency says, and the way to change it, which is iOS
/// Settings. No reminder and no second ask. Before iOS has asked, the row
/// asks — because the person tapped it.
class TrackingStatusRow extends ConsumerStatefulWidget {
  const TrackingStatusRow({super.key});

  /// iOS Settings, on LastReel's own page.
  static final appSettings = Uri.parse('app-settings:');

  @override
  ConsumerState<TrackingStatusRow> createState() => _TrackingStatusRowState();
}

class _TrackingStatusRowState extends ConsumerState<TrackingStatusRow> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Fresh each time Privacy opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(trackingStatusProvider);
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Back from iOS Settings: read it again.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) ref.invalidate(trackingStatusProvider);
  }

  Future<void> _onTap(TrackingAuthorizationStatus? status) async {
    if (status == TrackingAuthorizationStatus.notDetermined) {
      final result = await ref.read(trackingAuthorizationProvider).request();
      ref.read(analyticsProvider).logEvent('att_result', {'status': result.name, 'source': 'privacy'});
      ref.invalidate(trackingStatusProvider);
      return;
    }
    await ref.read(externalLinksProvider).openUrl(TrackingStatusRow.appSettings);
  }

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final t = context.type;
    final status = ref.watch(trackingStatusProvider).value;
    final subtitle = switch (status) {
      TrackingAuthorizationStatus.authorized => 'On · iOS tracking is allowed for LastReel',
      TrackingAuthorizationStatus.notDetermined => 'Off · iOS hasn’t asked yet',
      TrackingAuthorizationStatus.restricted => 'Off · iOS tracking is restricted on this device',
      _ => 'Off · iOS tracking is turned off for LastReel',
    };
    return EcGroupRow(
      title: 'Ad personalisation',
      subtitle: subtitle,
      trailing: Text(
        status == TrackingAuthorizationStatus.notDetermined ? 'Choose ›' : 'Change in iOS Settings ›',
        style: t.bodyS.copyWith(fontSize: 13, fontWeight: FontWeight.w600, color: p.accent),
      ),
      onTap: () => _onTap(status),
    );
  }
}
