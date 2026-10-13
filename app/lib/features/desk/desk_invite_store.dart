import 'package:shared_preferences/shared_preferences.dart';

/// When the desk invite (1.8) may show again on this device.
abstract interface class DeskInviteStore {
  /// "Don't show this again".
  bool get turnedOff;

  /// Shown, or put off with "Not now"; not before this.
  DateTime? get quietUntil;

  Future<void> quietUntilDate(DateTime until);
  Future<void> turnOff();
}

class PreferencesDeskInviteStore implements DeskInviteStore {
  static const _off = 'desk_invite_off';
  static const _until = 'desk_invite_quiet_until';

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
  Future<void> quietUntilDate(DateTime until) => _prefs.setInt(_until, until.toUtc().millisecondsSinceEpoch);

  @override
  Future<void> turnOff() => _prefs.setBool(_off, true);
}

/// In-memory implementation, for tests.
class InMemoryDeskInviteStore implements DeskInviteStore {
  @override
  bool turnedOff;

  @override
  DateTime? quietUntil;

  InMemoryDeskInviteStore({this.turnedOff = false, this.quietUntil});

  @override
  Future<void> quietUntilDate(DateTime until) async => quietUntil = until;

  @override
  Future<void> turnOff() async => turnedOff = true;
}
