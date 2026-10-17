import 'package:shared_preferences/shared_preferences.dart';

/// How the last rating ask ended.
enum ReviewAnswer {
  /// Never answered (or never asked).
  none,

  /// "Not now", or closed without picking.
  later,

  /// One to three stars — went to the team, not the store.
  low,

  /// Four or five stars — sent on to the store's review card.
  rated,
}

/// The rating prompt's history on this device: when it was last asked, how
/// often, and how the last ask ended. Device-local, like the prompt itself.
abstract interface class ReviewPromptStore {
  DateTime? get lastAsked;
  int get timesAsked;
  ReviewAnswer get lastAnswer;

  Future<void> markAsked(DateTime at);
  Future<void> recordAnswer(ReviewAnswer answer);
}

class PreferencesReviewPromptStore implements ReviewPromptStore {
  static const _lastAsked = 'review_prompt_last_asked';
  static const _times = 'review_prompt_times_asked';
  static const _answer = 'review_prompt_answer';

  /// The one-time flag from before the prompt could come back: an install
  /// that was asked then reads as asked once, at the moment it updated —
  /// its answer isn't known, so it may be asked again 30 days later.
  static const _legacyAsked = 'review_prompt_asked';

  final SharedPreferences _prefs;

  PreferencesReviewPromptStore(this._prefs) {
    if ((_prefs.getBool(_legacyAsked) ?? false) && _prefs.getInt(_lastAsked) == null) {
      _prefs
        ..setInt(_lastAsked, DateTime.now().toUtc().millisecondsSinceEpoch)
        ..setInt(_times, 1)
        ..remove(_legacyAsked);
    }
  }

  @override
  DateTime? get lastAsked {
    final ms = _prefs.getInt(_lastAsked);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
  }

  @override
  int get timesAsked => _prefs.getInt(_times) ?? 0;

  @override
  ReviewAnswer get lastAnswer =>
      ReviewAnswer.values.where((a) => a.name == _prefs.getString(_answer)).firstOrNull ?? ReviewAnswer.none;

  @override
  Future<void> markAsked(DateTime at) async {
    await _prefs.setInt(_lastAsked, at.toUtc().millisecondsSinceEpoch);
    await _prefs.setInt(_times, timesAsked + 1);
    await _prefs.setString(_answer, ReviewAnswer.none.name);
  }

  @override
  Future<void> recordAnswer(ReviewAnswer answer) => _prefs.setString(_answer, answer.name);
}

/// In-memory implementation, for tests.
class InMemoryReviewPromptStore implements ReviewPromptStore {
  @override
  DateTime? lastAsked;

  @override
  int timesAsked;

  @override
  ReviewAnswer lastAnswer;

  /// [asked] stands for a device that has already rated (never asked again).
  InMemoryReviewPromptStore({bool asked = false, this.lastAsked, this.timesAsked = 0, this.lastAnswer = ReviewAnswer.none}) {
    if (asked) this.asked = true;
  }

  /// Whether it has been asked at all.
  bool get asked => lastAsked != null;

  set asked(bool value) {
    lastAsked = value ? DateTime.utc(2000) : null;
    timesAsked = value ? 1 : 0;
    lastAnswer = value ? ReviewAnswer.rated : ReviewAnswer.none;
  }

  @override
  Future<void> markAsked(DateTime at) async {
    lastAsked = at;
    timesAsked++;
    lastAnswer = ReviewAnswer.none;
  }

  @override
  Future<void> recordAnswer(ReviewAnswer answer) async => lastAnswer = answer;
}
