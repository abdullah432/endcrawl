import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/entitlement.dart';

/// Where a plan purchase started, for the trial funnel's analytics.
enum PlanSource {
  library('library'),
  slotsFull('slots_full'),
  paywall('paywall'),
  settings('settings');

  final String analyticsName;
  const PlanSource(this.analyticsName);
}

class PlanState {
  final List<PlanOffer> offers;
  final PlanOffer? selected;
  final bool loading;
  final bool purchasing;
  final bool restoring;
  final String? message;

  const PlanState({
    this.offers = const [],
    this.selected,
    this.loading = true,
    this.purchasing = false,
    this.restoring = false,
    this.message,
  });
  bool get busy => purchasing || restoring;

  PlanState copyWith({
    List<PlanOffer>? offers,
    PlanOffer? selected,
    bool? loading,
    bool? purchasing,
    bool? restoring,
    String? message,
    bool clearMessage = false,
  }) => PlanState(
    offers: offers ?? this.offers,
    selected: selected ?? this.selected,
    loading: loading ?? this.loading,
    purchasing: purchasing ?? this.purchasing,
    restoring: restoring ?? this.restoring,
    message: clearMessage ? null : (message ?? this.message),
  );
}

class PlanController extends Notifier<PlanState> {
  @override
  PlanState build() {
    ref.watch(currentUidProvider);
    unawaited(Future.microtask(loadOffers));
    return const PlanState();
  }

  Future<void> loadOffers() async {
    if (!ref.mounted) return;
    final uid = ref.read(currentUidProvider);
    state = state.copyWith(loading: true, clearMessage: true);
    final result = await ref.read(entitlementRepositoryProvider).offers();
    if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
    state = switch (result) {
      Ok(:final value) => state.copyWith(
        offers: value,
        loading: false,
        selected: value.where((o) => o.period == BillingPeriod.yearly).firstOrNull ?? value.firstOrNull,
      ),
      Err(:final failure) => state.copyWith(loading: false, message: failure.message),
    };
  }

  void select(PlanOffer offer) {
    if (state.busy) return;
    state = state.copyWith(selected: offer, clearMessage: true);
    if (offer.hasTrial) {
      ref.read(analyticsProvider).logEvent('trial_plan_selected', {'plan': offer.period.name});
    }
  }

  /// Buys — or, where the store offers one, starts the free trial of — the
  /// selected plan. [source] is where the user started, for analytics.
  Future<bool> purchase({PlanSource source = PlanSource.paywall}) async {
    final offer = state.selected;
    if (state.busy || state.loading || offer == null) return false;
    final uid = ref.read(currentUidProvider);
    state = state.copyWith(purchasing: true, clearMessage: true);
    final result = await ref.read(entitlementRepositoryProvider).purchase(offer);
    if (!ref.mounted || ref.read(currentUidProvider) != uid) return false;
    state = switch (result) {
      Ok() => state.copyWith(purchasing: false),
      Err(:final failure) => state.copyWith(
        purchasing: false,
        message: failure.kind == FailureKind.cancelled ? null : failure.message,
        clearMessage: failure.kind == FailureKind.cancelled,
      ),
    };
    final ok = result is Ok<Entitlement> && result.value.isPro;
    if (ok && offer.hasTrial) {
      ref.read(analyticsProvider).logEvent('trial_started', {'plan': offer.period.name, 'source': source.analyticsName});
    }
    return ok;
  }

  Future<void> restore() async {
    if (state.busy) return;
    final uid = ref.read(currentUidProvider);
    state = state.copyWith(restoring: true, clearMessage: true);
    final result = await ref.read(entitlementRepositoryProvider).restore();
    if (!ref.mounted || ref.read(currentUidProvider) != uid) return;
    state = switch (result) {
      Ok(:final value) => state.copyWith(
        restoring: false,
        message: value.isPro ? 'Pro restored.' : 'No active subscription found.',
      ),
      Err(:final failure) => state.copyWith(restoring: false, message: failure.message),
    };
  }
}

final planControllerProvider = NotifierProvider.autoDispose<PlanController, PlanState>(PlanController.new);
