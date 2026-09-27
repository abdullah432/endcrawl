import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/entitlement.dart';

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
    if (!state.busy) state = state.copyWith(selected: offer, clearMessage: true);
  }

  Future<bool> purchase() async {
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
    return result is Ok<Entitlement> && result.value.isPro;
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
