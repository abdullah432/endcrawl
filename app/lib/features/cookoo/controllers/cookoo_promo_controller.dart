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
///
/// Each moment is logged twice: as LastReel's own `cookoo_*` event, and as
/// GA4's standard promotion event (`view_promotion` for an impression,
/// `select_promotion` for a click), so COOKOO's brand advertising shows in
/// Google Analytics' Promotions report — impressions, clicks and
/// click-through per slide and per surface (`location_id`).
class CookooPromoController extends Notifier<CookooPromoState> {
  /// Slides already reported this session — `cookoo_card_view` fires once
  /// per slide per app run, not on every swipe back.
  final _viewed = <String>{};

  @override
  CookooPromoState build() => CookooPromoState(hidden: ref.read(cookooStoreProvider).promoHidden);

  void _log(String name, Map<String, Object> parameters) => ref.read(analyticsProvider).logEvent(name, parameters);

  Map<String, Object> _slide(int index) => {'slide': cookooSlides[index].id, 'index': index};

  /// GA4's promotion parameters for [creative] (a slide id, `site`, or an
  /// app's name) on [surface] — `phone`, `tablet_landscape`, …
  void _promotion(String event, String creative, String? surface, {int? slot}) => _log(event, {
    'promotion_id': 'cookoo_from_the_makers',
    'promotion_name': 'COOKOO · From the makers',
    'creative_name': creative,
    'creative_slot': slot == null ? creative : 'slide_${slot + 1}',
    'location_id': surface ?? 'phone',
  });

  /// An impression: a slide at least half on screen, once per slide per run.
  void viewed(int index, {String? surface}) {
    if (!_viewed.add(cookooSlides[index].id)) return;
    _log('cookoo_card_view', {..._slide(index), 'surface': ?surface});
    _promotion('view_promotion', cookooSlides[index].id, surface, slot: index);
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

  /// A click on "Tell us your idea".
  void ctaTapped(String source, {String? surface}) {
    _log('cookoo_cta_tap', {'source': source, 'surface': ?surface});
    final slot = cookooSlides.indexWhere((s) => s.id == source);
    _promotion('select_promotion', source, surface, slot: slot < 0 ? null : slot);
  }

  /// A visit to cookoo.dev, from a slide's footer or the contact screens.
  void siteOpened(String source, {String? surface}) {
    _log('cookoo_site_open', {'source': source, 'surface': ?surface});
    _promotion('select_promotion', 'site_$source', surface);
  }

  /// "Get" on one of COOKOO's other apps.
  void otherAppTapped(String app, {String? surface}) {
    _log('cookoo_other_app_tap', {'app': app, 'surface': ?surface});
    _promotion('select_promotion', 'app_$app', surface);
  }
}

final cookooPromoProvider = NotifierProvider<CookooPromoController, CookooPromoState>(CookooPromoController.new);
