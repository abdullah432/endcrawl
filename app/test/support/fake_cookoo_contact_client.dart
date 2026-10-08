import 'package:lastreel/features/cookoo/data/cookoo_contact_client.dart';

/// Records contact requests instead of posting them; [next] decides how
/// each one goes.
class FakeCookooContactClient implements CookooContactClient {
  CookooDelivery next = CookooDelivery.sent;
  final sent = <Map<String, Object?>>[];

  @override
  Future<CookooDelivery> send(Map<String, Object?> payload) async {
    if (next == CookooDelivery.sent) sent.add(payload);
    return next;
  }
}
