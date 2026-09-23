import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/entitlement.dart';

class PlanState {
  final PlanOffer selected;
  final bool purchasing;
  final bool restoring;

  /// A message for the person — a failed purchase, or the outcome of a
  /// restore. Cleared on the next action.
  final String? message;

  const PlanState({this.selected = PlanOffer.yearly, this.purchasing = false, this.restoring = false, this.message});

  bool get busy => purchasing || restoring;

  PlanState copyWith({PlanOffer? selected, bool? purchasing, bool? restoring, String? message, bool clearMessage = false}) {
    return PlanState(
      selected: selected ?? this.selected,
      purchasing: purchasing ?? this.purchasing,
      restoring: restoring ?? this.restoring,
      message: clearMessage ? null : (message ?? this.message),
    );
  }
}

/// Drives the Pro sheet (6.5) and the Restore rows on Settings.
///
/// Everything goes through [EntitlementRepository]; when a store-backed
/// implementation lands, this controller and every screen above it stay as
/// they are. The yearly plan is preselected, as in the design.
class PlanController extends Notifier<PlanState> {
  @override
  PlanState build() => const PlanState();

  void select(PlanOffer offer) => state = state.copyWith(selected: offer, clearMessage: true);

  /// True when the purchase went through.
  Future<bool> purchase() async {
    if (state.busy) return false;
    state = state.copyWith(purchasing: true, clearMessage: true);
    final result = await ref.read(entitlementRepositoryProvider).purchase(state.selected);
    state = switch (result) {
      Ok() => state.copyWith(purchasing: false),
      Err(:final failure) => state.copyWith(purchasing: false, message: failure.message),
    };
    return result is Ok;
  }

  Future<void> restore() async {
    if (state.busy) return;
    state = state.copyWith(restoring: true, clearMessage: true);
    final result = await ref.read(entitlementRepositoryProvider).restore();
    state = switch (result) {
      Ok(:final value) =>
        state.copyWith(restoring: false, message: value.isPro ? 'Pro restored.' : 'No active subscription found.'),
      Err(:final failure) => state.copyWith(restoring: false, message: failure.message),
    };
  }
}

final planControllerProvider = NotifierProvider.autoDispose<PlanController, PlanState>(PlanController.new);
