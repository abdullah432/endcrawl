import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bootstrap.dart';

final webAccessRequiredProvider = Provider<bool>((ref) => kIsWeb);
final webAccessAllowedProvider = Provider<bool>((ref) {
  if (!ref.watch(webAccessRequiredProvider)) return true;
  final access = ref.watch(entitlementProvider);
  return !access.isLoading && access.value?.isPro == true;
});
