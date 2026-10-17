import 'package:shared_preferences/shared_preferences.dart';

/// When the desk invite (1.8) may show again on this device.
abstract interface class DeskInviteStore {
  /// "Don't show this again".
  bool get turnedOff;

  /// Shown, or put off with "Not now"; not before this.
  DateTime? get quietUntil;

  /// How many times the app has been started on this device, this one
  /// included.
  int get sessions;

  Future<void> quietUntilDate(DateTime until);
  Future<void> turnOff();

  /// Counts this start of the app; called once, before the first frame.
  Future<void> countSession();
}

class PreferencesDeskInviteStore implements DeskInviteStore {
  static const _off = 'desk_invite_off';
  static const _until = 'desk_invite_quiet_until';
  static const _sessions = 'desk_invite_sessions';

  final SharedPreferences _prefs;
  PreferencesDeskInviteStore(this._prefs);

  @override
  bool get turnedOff => _prefs.getBool(_off) ?? false;

  @override
  DateTime? get quietUntil {
    final ms = _prefs.getInt(_until);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  int get sessions => _prefs.getInt(_sessions) ?? 0;

  @override
  Future<void> quietUntilDate(DateTime until) => _prefs.setInt(_until, until.toUtc().millisecondsSinceEpoch);

  @override
  Future<void> turnOff() => _prefs.setBool(_off, true);

  @override
  Future<void> countSession() => _prefs.setInt(_sessions, sessions + 1);
}

/// In-memory implementation, for tests.
class InMemoryDeskInviteStore implements DeskInviteStore {
  @override
  bool turnedOff;

  @override
  DateTime? quietUntil;

  /// Past the first few by default, so tests see the invite unless they
  /// are about a new install.
  @override
  int sessions;

  InMemoryDeskInviteStore({this.turnedOff = false, this.quietUntil, this.sessions = 10});

  @override
  Future<void> quietUntilDate(DateTime until) async => quietUntil = until;

  @override
  Future<void> turnOff() async => turnedOff = true;

  @override
  Future<void> countSession() async => sessions++;
}
