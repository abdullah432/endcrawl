import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';

/// The library's plan card (1.1a). It has no dismiss: it shows whenever a
/// free library is full, so all this tracks is that it was seen.
class TrialOfferController {
  final Ref _ref;
  const TrialOfferController(this._ref);

  void shown() => _ref.read(analyticsProvider).logEvent('trial_card_shown');
}

final trialOfferControllerProvider = Provider<TrialOfferController>(TrialOfferController.new);
