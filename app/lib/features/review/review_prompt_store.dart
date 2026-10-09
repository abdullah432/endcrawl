import 'package:shared_preferences/shared_preferences.dart';

/// Whether this device has already been asked for a rating. Device-local:
/// the prompt is about this install, and is asked at most once.
abstract interface class ReviewPromptStore {
  bool get asked;
  Future<void> markAsked();
}

class PreferencesReviewPromptStore implements ReviewPromptStore {
  static const _key = 'review_prompt_asked';

  final SharedPreferences _prefs;

  PreferencesReviewPromptStore(this._prefs);

  @override
  bool get asked => _prefs.getBool(_key) ?? false;

  @override
  Future<void> markAsked() => _prefs.setBool(_key, true);
}

/// In-memory implementation, for tests.
class InMemoryReviewPromptStore implements ReviewPromptStore {
  @override
  bool asked;

  InMemoryReviewPromptStore({this.asked = false});

  @override
  Future<void> markAsked() async => asked = true;
}
