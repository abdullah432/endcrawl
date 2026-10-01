import 'package:shared_preferences/shared_preferences.dart';

/// Which project this *device* had open, and whether it was left open.
///
/// Deliberately device-local rather than fields on the project document:
/// with a cloud-backed store the document is shared across every device the
/// user signs in on, so "I was editing this when the app died" would follow
/// them to their tablet and offer a recovery for a session that never
/// happened there. Content belongs in Firestore; session state belongs here.
class SessionState {
  /// The project most recently opened on this device.
  final String? lastOpenedProjectId;

  /// Set while the editor holds a project open, cleared on a clean close.
  /// Still set at launch means the app was killed mid-edit.
  final String? leftOpenProjectId;

  const SessionState({this.lastOpenedProjectId, this.leftOpenProjectId});

  bool wasLeftOpen(String projectId) => leftOpenProjectId == projectId;
}

abstract interface class SessionStore {
  Future<SessionState> read();
  Future<void> setLastOpened(String? projectId);
  Future<void> setLeftOpen(String? projectId);

  /// Until when the library's free-trial card (1.1a) stays dismissed.
  Future<DateTime?> trialOfferHiddenUntil();
  Future<void> hideTrialOfferUntil(DateTime until);
}

class PreferencesSessionStore implements SessionStore {
  static const _lastOpenedKey = 'session.lastOpenedProjectId';
  static const _leftOpenKey = 'session.leftOpenProjectId';
  static const _trialOfferHiddenKey = 'plan.trialOfferHiddenUntil';

  final SharedPreferences _prefs;

  PreferencesSessionStore(this._prefs);

  @override
  Future<SessionState> read() async {
    return SessionState(
      lastOpenedProjectId: _prefs.getString(_lastOpenedKey),
      leftOpenProjectId: _prefs.getString(_leftOpenKey),
    );
  }

  @override
  Future<void> setLastOpened(String? projectId) => _write(_lastOpenedKey, projectId);

  @override
  Future<void> setLeftOpen(String? projectId) => _write(_leftOpenKey, projectId);

  @override
  Future<DateTime?> trialOfferHiddenUntil() async {
    final millis = _prefs.getInt(_trialOfferHiddenKey);
    return millis == null ? null : DateTime.fromMillisecondsSinceEpoch(millis);
  }

  @override
  Future<void> hideTrialOfferUntil(DateTime until) => _prefs.setInt(_trialOfferHiddenKey, until.millisecondsSinceEpoch);

  Future<void> _write(String key, String? value) async {
    if (value == null) {
      await _prefs.remove(key);
    } else {
      await _prefs.setString(key, value);
    }
  }
}

/// In-memory implementation, for tests and for any context without platform
/// storage.
class InMemorySessionStore implements SessionStore {
  SessionState _state;

  InMemorySessionStore([this._state = const SessionState()]);

  DateTime? hiddenUntil;

  @override
  Future<DateTime?> trialOfferHiddenUntil() async => hiddenUntil;

  @override
  Future<void> hideTrialOfferUntil(DateTime until) async => hiddenUntil = until;

  @override
  Future<SessionState> read() async => _state;

  @override
  Future<void> setLastOpened(String? projectId) async => _state = SessionState(
        lastOpenedProjectId: projectId,
        leftOpenProjectId: _state.leftOpenProjectId,
      );

  @override
  Future<void> setLeftOpen(String? projectId) async => _state = SessionState(
        lastOpenedProjectId: _state.lastOpenedProjectId,
        leftOpenProjectId: projectId,
      );
}
