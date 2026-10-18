import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Rebuild with --dart-define=IOS_FREE_LAUNCH=false to restore subscriptions.
/// This flag never changes stored projects or account entitlements.
final iosFreeLaunchFlagProvider = Provider<bool>(
  (ref) => const bool.fromEnvironment('IOS_FREE_LAUNCH', defaultValue: true),
);
