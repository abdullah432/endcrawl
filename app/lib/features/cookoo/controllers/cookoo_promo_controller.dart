import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../data/cookoo_store.dart';
import '../models/cookoo_content.dart';

/// Device-local COOKOO state. Overridden in `main` with the
/// SharedPreferences-backed store, and in tests with an in-memory one.
final cookooStoreProvider = Provider<CookooStore>((ref) {
  throw StateError('cookooStoreProvider was not overridden — see bootstrap().');
});

class CookooPromoState {
  /// Saved: the card stays hidden across launches until turned back on.
  final bool hidden;

  /// Hidden from the card itself this session, so the "Undo" row shows in
  /// its place. Not saved — next launch the slot is simply empty.
  final bool undoable;

  const CookooPromoState({required this.hidden, this.undoable = false});
}

/// The studio card in Settings: hiding it, and the card's analytics.
class CookooPromoController extends Notifier<CookooPromoState> {
  /// Slides already reported this session — `cookoo_card_view` fires once
  /// per slide per app run, not on every swipe back.
  final _viewed = <String>{};

  @override
  CookooPromoState build() => CookooPromoState(hidden: ref.read(cookooStoreProvider).promoHidden);

  void _log(String name, Map<String, Object> parameters) => ref.read(analyticsProvider).logEvent(name, parameters);

  Map<String, Object> _slide(int index) => {'slide': cookooSlides[index].id, 'index': index};

  void viewed(int index) {
    if (_viewed.add(cookooSlides[index].id)) _log('cookoo_card_view', _slide(index));
  }

  void swiped(int index) => _log('cookoo_card_swipe', _slide(index));

  /// "Hide" on the card: saved at once, with Undo for the rest of the session.
  void hide(int index) {
    state = const CookooPromoState(hidden: true, undoable: true);
    ref.read(cookooStoreProvider).setPromoHidden(true);
    _log('cookoo_card_hide', _slide(index));
  }

  void undo() => setShown(true);

  /// The "Show COOKOO studio card" switch.
  void setShown(bool shown) {
    state = CookooPromoState(hidden: !shown);
    ref.read(cookooStoreProvider).setPromoHidden(!shown);
  }

  void ctaTapped(String source) => _log('cookoo_cta_tap', {'source': source});

  void siteOpened(String source) => _log('cookoo_site_open', {'source': source});
}

final cookooPromoProvider = NotifierProvider<CookooPromoController, CookooPromoState>(CookooPromoController.new);
