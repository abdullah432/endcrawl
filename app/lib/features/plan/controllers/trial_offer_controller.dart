import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';

/// Until when this device keeps the library's free-trial card (1.1a)
/// dismissed; null when it never has been.
final trialOfferHiddenUntilProvider = FutureProvider<DateTime?>((ref) {
  return ref.watch(sessionStoreProvider).trialOfferHiddenUntil();
});

/// Whether the trial card is dismissed right now.
final trialOfferHiddenProvider = Provider<bool>((ref) {
  final until = ref.watch(trialOfferHiddenUntilProvider).value;
  return until != null && ref.read(clockProvider)().isBefore(until);
});

class TrialOfferController {
  final Ref _ref;
  const TrialOfferController(this._ref);

  /// ✕ on the card: gone for a week, and the sponsored slot comes back.
  static const hideFor = Duration(days: 7);

  Future<void> dismiss() async {
    await _ref.read(sessionStoreProvider).hideTrialOfferUntil(_ref.read(clockProvider)().add(hideFor));
    _ref.invalidate(trialOfferHiddenUntilProvider);
    _ref.read(analyticsProvider).logEvent('trial_card_dismissed');
  }

  void shown() => _ref.read(analyticsProvider).logEvent('trial_card_shown');
}

final trialOfferControllerProvider = Provider<TrialOfferController>(TrialOfferController.new);
