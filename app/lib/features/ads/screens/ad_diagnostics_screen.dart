import 'package:app_tracking_transparency/app_tracking_transparency.dart';
import '../../../core/config/ad_config.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ads_providers.dart';
import '../data/ad_diagnostics.dart';
import '../data/admob_ad_service.dart';

class AdDiagnosticsScreen extends ConsumerWidget {
  const AdDiagnosticsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => Scaffold(
    appBar: AppBar(title: const Text('Ad diagnostics')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text(
            'Visit Home and Rendering, then return here. Logs remain on this device '
            'until the app closes. Ad Inspector requires an AdMob test device.',
          ),
        ),
        Text(
          AdUnits.diagnosticNativeTestAds
              ? 'Native units: Google sample ads'
              : 'Native units: production',
        ),
        TextButton(
          onPressed: () async {
            try {
              final status =
                  await AppTrackingTransparency.trackingAuthorizationStatus;
              final idfa =
                  await AppTrackingTransparency.getAdvertisingIdentifier();
              recordAdDiagnostic('ATT: ${status.name}; current IDFA: $idfa');
            } catch (error) {
              recordAdDiagnostic('IDFA read failed: $error');
            }
          },
          child: const Text('Read tracking status / IDFA'),
        ),
        Wrap(
          spacing: 12,
          children: [
            TextButton(
              onPressed: () async {
                final service = ref.read(adServiceProvider);
                if (service is AdMobAdService) await service.openInspector();
              },
              child: const Text('Open Ad Inspector'),
            ),
            TextButton(
              onPressed: () async {
                await Clipboard.setData(
                  ClipboardData(text: adDiagnosticEvents.value.join('\n')),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Diagnostics copied')),
                  );
                }
              },
              child: const Text('Copy log'),
            ),
          ],
        ),
        Expanded(
          child: ValueListenableBuilder<List<String>>(
            valueListenable: adDiagnosticEvents,
            builder: (context, events, _) => SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: SelectableText(
                events.isEmpty
                    ? 'No ad requests recorded yet.'
                    : events.join('\n\n'),
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
