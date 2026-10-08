import 'package:shared_preferences/shared_preferences.dart';

/// Device-local state for the COOKOO studio card: whether it was hidden,
/// and contact requests waiting for a connection.
///
/// Reads are synchronous so Settings can decide whether to show the card on
/// its first frame.
abstract interface class CookooStore {
  bool get promoHidden;
  Future<void> setPromoHidden(bool hidden);

  /// Queued contact requests, each a JSON-encoded payload, oldest first.
  List<String> get pendingContacts;
  Future<void> setPendingContacts(List<String> payloads);
}

class PreferencesCookooStore implements CookooStore {
  static const _hiddenKey = 'cookoo_promo_hidden';
  static const _queueKey = 'cookoo_contact_queue';

  final SharedPreferences _prefs;

  PreferencesCookooStore(this._prefs);

  @override
  bool get promoHidden => _prefs.getBool(_hiddenKey) ?? false;

  @override
  Future<void> setPromoHidden(bool hidden) => _prefs.setBool(_hiddenKey, hidden);

  @override
  List<String> get pendingContacts => _prefs.getStringList(_queueKey) ?? const [];

  @override
  Future<void> setPendingContacts(List<String> payloads) =>
      payloads.isEmpty ? _prefs.remove(_queueKey) : _prefs.setStringList(_queueKey, payloads);
}

/// In-memory implementation, for tests.
class InMemoryCookooStore implements CookooStore {
  @override
  bool promoHidden;

  @override
  List<String> pendingContacts;

  InMemoryCookooStore({this.promoHidden = false, List<String>? pendingContacts})
    : pendingContacts = pendingContacts ?? [];

  @override
  Future<void> setPromoHidden(bool hidden) async => promoHidden = hidden;

  @override
  Future<void> setPendingContacts(List<String> payloads) async => pendingContacts = [...payloads];
}
