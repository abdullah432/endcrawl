import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../bootstrap.dart';
import '../../../data/repositories/web_billing_repository.dart';
import '../../access/controllers/web_access.dart';

final webBillingEnabledProvider = Provider<bool>((ref) =>
  ref.watch(runningOnWebProvider) && const bool.fromEnvironment('WEB_BILLING_ENABLED'));

final webBillingRepositoryProvider = Provider<WebBillingRepository>((ref) =>
  FirebaseWebBillingRepository(FirebaseFunctions.instance));

final webBillingCatalogProvider = FutureProvider.autoDispose<WebBillingCatalog>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null || !ref.watch(webBillingEnabledProvider)) return Future.value(const WebBillingCatalog());
  return ref.watch(webBillingRepositoryProvider).catalog();
});

/// The same tab avoids popup blockers after an asynchronous authenticated call.
final billingNavigationProvider = Provider<Future<bool> Function(Uri)>((ref) =>
  (uri) => launchUrl(uri, webOnlyWindowName: '_self'));

final webCheckoutReturnedProvider = Provider<bool>((ref) =>
  ref.watch(webBillingEnabledProvider) && Uri.base.queryParameters['billing'] == 'return');

String webBillingError(Object error) => error is FirebaseFunctionsException && error.message != null
    ? error.message!
    : 'Could not reach billing. Please try again.';
