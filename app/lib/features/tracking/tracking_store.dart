import 'package:shared_preferences/shared_preferences.dart';

/// What the tracking pre-prompt needs to remember on this device: when the
/// app was first opened here, and whether the pre-prompt has had its one
/// showing.
abstract interface class TrackingStore {
  /// The first launch on this device — the install, as near as the app can
  /// tell. A device that updated from a build without this counts from the
  /// update.
  DateTime? get firstSeen;

  /// The pre-prompt has shown, or iOS had already decided: never again.
  bool get prePromptDone;

  /// Records [now] as the first launch, unless one is already recorded.
  Future<void> recordFirstSeen(DateTime now);

  Future<void> markPrePromptDone();
}

class PreferencesTrackingStore implements TrackingStore {
  static const _firstSeen = 'install_first_seen_at';
  static const _done = 'att_preprompt_shown';

  final SharedPreferences _prefs;
  PreferencesTrackingStore(this._prefs);

  @override
  DateTime? get firstSeen {
    final ms = _prefs.getInt(_firstSeen);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  bool get prePromptDone => _prefs.getBool(_done) ?? false;

  @override
  Future<void> recordFirstSeen(DateTime now) async {
    if (_prefs.getInt(_firstSeen) != null) return;
    await _prefs.setInt(_firstSeen, now.toUtc().millisecondsSinceEpoch);
  }

  @override
  Future<void> markPrePromptDone() => _prefs.setBool(_done, true);
}

/// In-memory implementation, for tests. No first launch by default, so the
/// pre-prompt never comes up in tests about something else.
class InMemoryTrackingStore implements TrackingStore {
  @override
  DateTime? firstSeen;

  @override
  bool prePromptDone;

  InMemoryTrackingStore({this.firstSeen, this.prePromptDone = false});

  @override
  Future<void> recordFirstSeen(DateTime now) async => firstSeen ??= now.toUtc();

  @override
  Future<void> markPrePromptDone() async => prePromptDone = true;
}
