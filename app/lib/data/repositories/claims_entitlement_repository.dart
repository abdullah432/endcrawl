import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';

import '../../core/config/app_links.dart';
import '../../core/config/billing_config.dart';
import '../../core/result.dart';
import '../../domain/models/entitlement.dart';
import 'entitlement_repository.dart';

/// The plan on the web, read from the Firebase sign-in token.
///
/// Pro is bought in the mobile app (Google Play, through RevenueCat).
/// RevenueCat's Firebase extension stamps the account's active
/// entitlements onto its Firebase Auth token as a custom claim
/// ([BillingConfig.entitlementsClaim]); only the server can set it, so the
/// browser can read Pro but never grant it. The web never sells: [offers]
/// and [purchase] answer that billing happens in the app, and [restore] is
/// "check access" — it forces a fresh token so a purchase made minutes ago
/// shows up without signing out.
class ClaimsEntitlementRepository implements EntitlementRepository {
  final FirebaseAuth _auth;
  final _rechecked = StreamController<Entitlement>.broadcast();

  ClaimsEntitlementRepository(this._auth);

  static const notSoldHere = AppFailure(
    FailureKind.unknown,
    'LastReel Pro is bought in the mobile app, through Google Play.',
  );

  @override
  Stream<Entitlement> watch() {
    // Token changes (sign-in, refresh) and explicit re-checks, merged.
    final controller = StreamController<Entitlement>();
    StreamSubscription<User?>? tokens;
    StreamSubscription<Entitlement>? rechecks;
    controller.onListen = () {
      tokens = _auth.idTokenChanges().listen((user) async {
        controller.add(await _read(user));
      }, onError: controller.addError);
      rechecks = _rechecked.stream.listen(controller.add);
    };
    controller.onCancel = () async {
      await tokens?.cancel();
      await rechecks?.cancel();
    };
    return controller.stream;
  }

  Future<Entitlement> _read(User? user, {bool refresh = false}) async {
    if (user == null) return const Entitlement.free();
    try {
      final token = await user.getIdTokenResult(refresh);
      return entitlementFromClaims(token.claims);
    } on FirebaseAuthException {
      return const Entitlement.free();
    }
  }

  @override
  Future<Result<List<PlanOffer>>> offers() async => const Err(notSoldHere);

  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async => const Err(notSoldHere);

  /// Asks the server again: refreshes the token, then reads the claim.
  @override
  Future<Result<Entitlement>> restore() async {
    try {
      final entitlement = await _read(_auth.currentUser, refresh: true);
      _rechecked.add(entitlement);
      return Ok(entitlement);
    } on Object catch (e, s) {
      return Err(AppFailure(FailureKind.network, 'We couldn’t check right now. Try again.', cause: e, stackTrace: s));
    }
  }
}

/// Pro when the claim lists the Pro entitlement. Billing details (renewal,
/// period) live in Google Play, so the web shows status only.
Entitlement entitlementFromClaims(Map<String, dynamic>? claims) {
  final active = claims?[BillingConfig.entitlementsClaim];
  final isPro = active is List && active.contains(BillingConfig.entitlementId);
  return isPro ? Entitlement.pro(managementUrl: AppLinks.playSubscriptions) : const Entitlement.free();
}
