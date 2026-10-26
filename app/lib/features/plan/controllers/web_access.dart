import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../bootstrap.dart';
import '../../access/controllers/web_access.dart';

final webAccessRequiredProvider = Provider<bool>(
  (ref) => ref.watch(verifiedWorkspaceProvider),
);
final webAccessAllowedProvider = Provider<bool>((ref) {
  if (!ref.watch(webAccessRequiredProvider)) return true;
  final access = ref.watch(entitlementProvider);
  return !access.isLoading && access.value?.isPro == true;
});
