import 'package:cloud_functions/cloud_functions.dart';
import '../../domain/models/entitlement.dart';

class WebBillingCatalog {
  final bool enabled;
  final bool sandbox;
  final List<PlanOffer> offers;
  const WebBillingCatalog({
    this.enabled = false,
    this.sandbox = false,
    this.offers = const [],
  });

  factory WebBillingCatalog.fromJson(Map<String, dynamic> data) =>
      WebBillingCatalog(
        enabled: data['enabled'] == true,
        sandbox: data['environment'] == 'sandbox',
        offers: [
          for (final item in data['offers'] as List? ?? [])
            PlanOffer(
              period: item['period'] == 'yearly'
                  ? BillingPeriod.yearly
                  : BillingPeriod.monthly,
              price: item['price'] as String,
              detail: item['detail'] as String,
              packageId: item['packageId'] as String,
              badge: item['badge'] as String?,
              pricePerMonth: item['pricePerMonth'] as String?,
              isSandbox: data['environment'] == 'sandbox',
            ),
        ],
      );
}

abstract interface class WebBillingRepository {
  Future<WebBillingCatalog> catalog();
  Future<Uri> checkout(BillingPeriod period);
  Future<Uri> management();
}

Uri verifiedBillingUrl(String value, {required bool checkout}) {
  final uri = Uri.parse(value);
  final hosts = checkout
      ? ['pay.rev.cat']
      : [
          'apps.apple.com',
          'play.google.com',
          'customer-portal.paddle.com',
          'sandbox-customer-portal.paddle.com',
        ];
  if (uri.scheme != 'https' ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      !hosts.contains(uri.host)) {
    throw const FormatException('Invalid billing destination');
  }
  return uri;
}

class FirebaseWebBillingRepository implements WebBillingRepository {
  final FirebaseFunctions functions;
  FirebaseWebBillingRepository(this.functions);

  Future<Map<String, dynamic>> _call(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    final response = await functions.httpsCallable(name).call(data);
    return Map<String, dynamic>.from(response.data as Map);
  }

  @override
  Future<WebBillingCatalog> catalog() async =>
      WebBillingCatalog.fromJson(await _call('getWebBillingOptions'));
  @override
  Future<Uri> checkout(BillingPeriod period) async => verifiedBillingUrl(
    (await _call('createWebCheckout', {'period': period.name}))['url']
        as String,
    checkout: true,
  );
  @override
  Future<Uri> management() async => verifiedBillingUrl(
    (await _call('getBillingManagementUrl'))['url'] as String,
    checkout: false,
  );
}
