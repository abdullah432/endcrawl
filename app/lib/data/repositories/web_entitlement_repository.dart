import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart' show FirebaseFunctions;
import 'package:flutter/widgets.dart';
import '../../core/result.dart';
import '../../domain/models/entitlement.dart';
import 'entitlement_repository.dart';

Entitlement entitlementFromLedger(Map<String, dynamic> data, DateTime now) {
  DateTime? date(String key) {
    final value = data[key];
    return value is num && value.isFinite && value.abs() <= 8640000000000000
        ? DateTime.fromMillisecondsSinceEpoch(value.toInt(), isUtc: true)
        : null;
  }

  final expires = date('expiresAtMs');
  if (data['schemaVersion'] != 1 ||
      (data['expiresAtMs'] != null && expires == null) ||
      data['plan'] != 'pro' ||
      (expires != null && !expires.isAfter(now))) {
    return Entitlement.free(
      lapsed: data['lapsed'] == true || data['plan'] == 'pro',
    );
  }
  final uri = Uri.tryParse(
    data['managementUrl'] is String ? data['managementUrl'] as String : '',
  );
  return Entitlement.pro(
    period: switch (data['period']) {
      'monthly' => BillingPeriod.monthly,
      'yearly' => BillingPeriod.yearly,
      _ => null,
    },
    renewsAt: expires,
    willRenew: data['willRenew'] == true,
    trialEndsAt: date('trialEndsAtMs'),
    managementUrl:
        uri != null &&
            uri.scheme == 'https' &&
            ['apps.apple.com', 'play.google.com'].contains(uri.host)
        ? uri
        : null,
  );
}

/// Reads a server-owned ledger for this Firebase uid; never purchases on web.
class WebEntitlementRepository
    with WidgetsBindingObserver
    implements EntitlementRepository {
  final String uid;
  final FirebaseFirestore firestore;
  final FirebaseFunctions functions;
  final _updates = StreamController<Entitlement>.broadcast();
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _subscription;
  Timer? _expiry;
  Map<String, dynamic>? _ledger;
  Entitlement? _current;
  Future<Result<Entitlement>>? _refreshing;
  Object? _error;
  bool _disposed = false;

  WebEntitlementRepository({
    required this.uid,
    required this.firestore,
    required this.functions,
  }) {
    WidgetsBinding.instance.addObserver(this);
    _subscription = firestore
        .doc('billingEntitlements/$uid')
        .snapshots()
        .listen(
          (snapshot) {
            if (snapshot.data() case final data?) _accept(data);
          },
          onError: (Object error) {
            if (_current == null && !_disposed) {
              _error = error;
              _updates.addError(error);
            }
          },
        );
    unawaited(refresh());
  }

  void _accept(Map<String, dynamic> data) {
    if (_disposed) return;
    if (_ledger != null &&
        (data['sourceUpdatedAtMs'] as num? ?? 0) <
            (_ledger!['sourceUpdatedAtMs'] as num? ?? 0)) {
      return;
    }
    _ledger = data;
    _error = null;
    _current = entitlementFromLedger(data, DateTime.now());
    _updates.add(_current!);
    _expiry?.cancel();
    if (_current!.renewsAt case final at? when at.isAfter(DateTime.now())) {
      _expiry = Timer(at.difference(DateTime.now()), () {
        _accept(data);
        unawaited(refresh());
      });
    }
  }

  Future<Result<Entitlement>> refresh() =>
      _refreshing ??= _refresh().whenComplete(() => _refreshing = null);
  Future<Result<Entitlement>> _refresh() async {
    try {
      final response = await functions
          .httpsCallable('refreshEntitlement')
          .call();
      if (_disposed) {
        return const Err(
          AppFailure(FailureKind.cancelled, 'Your account changed.'),
        );
      }
      _accept(Map<String, dynamic>.from(response.data as Map));
      return Ok(_current!);
    } catch (_) {
      const failure = AppFailure(
        FailureKind.network,
        'Could not check Pro access. Please try again.',
      );
      if (!_disposed && _current == null) {
        _error = failure;
        _updates.addError(failure);
      }
      return const Err(failure);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  @override
  Stream<Entitlement> watch() => Stream.multi((controller) {
    if (_current case final value?) controller.add(value);
    if (_error case final error?) controller.addError(error);
    final subscription = _updates.stream.listen(
      controller.add,
      onError: controller.addError,
    );
    controller.onCancel = subscription.cancel;
  });
  @override
  Future<Result<List<PlanOffer>>> offers() async => const Ok([]);
  @override
  Future<Result<Entitlement>> purchase(PlanOffer offer) async => const Err(
    AppFailure(
      FailureKind.permission,
      'Subscribe in the mobile app using this same account.',
    ),
  );
  @override
  Future<Result<Entitlement>> restore() => refresh();
  void dispose() {
    _disposed = true;
    _subscription?.cancel();
    _expiry?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _updates.close();
  }
}
