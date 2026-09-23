import 'package:flutter/material.dart';

import '../../../core/widgets/ec_surfaces.dart';

/// A failure that isn't about one field — a provider outage, a cancelled
/// network call — shown in the same place on every auth screen.
class AuthErrorBanner extends StatelessWidget {
  final String? message;
  const AuthErrorBanner(this.message, {super.key});

  @override
  Widget build(BuildContext context) {
    if (message == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: EcNotice(tone: EcTone.warn, title: message!),
    );
  }
}
