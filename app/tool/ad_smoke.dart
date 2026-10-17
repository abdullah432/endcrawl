import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lastreel/core/theme/app_theme.dart';
import 'package:lastreel/features/ads/data/ad_service.dart';
import 'package:lastreel/features/ads/data/admob_ad_service.dart';

/// Developer smoke check for the real native ad factory and SDK. This
/// entry point always uses Google's sample units and never touches accounts.
void main() {
  if (!kDebugMode) throw StateError('Ad smoke checks require a debug build.');
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _AdSmoke());
}

class _AdSmoke extends StatefulWidget {
  const _AdSmoke();

  @override
  State<_AdSmoke> createState() => _AdSmokeState();
}

class _AdSmokeState extends State<_AdSmoke> {
  late final _ads = AdMobAdService(() => false);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ads.preloadAppOpen());
  }

  @override
  void dispose() {
    _ads.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    theme: buildLastReelTheme(),
    home: Scaffold(
      appBar: AppBar(title: const Text('AdMob test placements')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Google sample inventory · SDK/native factory smoke check',
          ),
          for (final placement in AdPlacement.values) ...[
            const SizedBox(height: 30),
            Text(placement.name),
            const SizedBox(height: 12),
            _ads.nativeAd(placement, framed: (creative) => creative),
          ],
        ],
      ),
    ),
  );
}
