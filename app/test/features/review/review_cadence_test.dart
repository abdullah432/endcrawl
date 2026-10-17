import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/features/review/review_prompt.dart';
import 'package:lastreel/features/review/review_prompt_store.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final now = DateTime.utc(2026, 10, 15);

  InMemoryReviewPromptStore askedDaysAgo(int days, ReviewAnswer answer, {int times = 1}) =>
      InMemoryReviewPromptStore(lastAsked: now.subtract(Duration(days: days)), timesAsked: times, lastAnswer: answer);

  test('a device that was never asked is due', () {
    expect(ReviewPrompt.due(InMemoryReviewPromptStore(), now), isTrue);
  });

  test('"Not now" waits 30 days', () {
    expect(ReviewPrompt.due(askedDaysAgo(10, ReviewAnswer.later), now), isFalse);
    expect(ReviewPrompt.due(askedDaysAgo(29, ReviewAnswer.later), now), isFalse);
    expect(ReviewPrompt.due(askedDaysAgo(30, ReviewAnswer.later), now), isTrue);
  });

  test('a low rating waits 30 days too', () {
    expect(ReviewPrompt.due(askedDaysAgo(5, ReviewAnswer.low), now), isFalse);
    expect(ReviewPrompt.due(askedDaysAgo(31, ReviewAnswer.low), now), isTrue);
  });

  test('once someone has rated, it never asks again', () {
    expect(ReviewPrompt.due(askedDaysAgo(400, ReviewAnswer.rated), now), isFalse);
  });

  test('no more than three asks in all', () {
    expect(ReviewPrompt.due(askedDaysAgo(60, ReviewAnswer.later, times: 2), now), isTrue);
    expect(ReviewPrompt.due(askedDaysAgo(60, ReviewAnswer.later, times: 3), now), isFalse);
  });

  test('an ask starts a new answer; the answer is kept', () async {
    SharedPreferences.setMockInitialValues({});
    final store = PreferencesReviewPromptStore(await SharedPreferences.getInstance());
    await store.markAsked(now);
    expect((store.timesAsked, store.lastAnswer, store.lastAsked), (1, ReviewAnswer.none, now));
    await store.recordAnswer(ReviewAnswer.later);
    expect(store.lastAnswer, ReviewAnswer.later);
  });

  test('a phone asked under the old one-time rule waits 30 days from the update', () async {
    SharedPreferences.setMockInitialValues({'review_prompt_asked': true});
    final prefs = await SharedPreferences.getInstance();
    final store = PreferencesReviewPromptStore(prefs);
    expect(store.timesAsked, 1);
    expect(store.lastAsked, isNotNull);
    expect(prefs.getBool('review_prompt_asked'), isNull);
    final updated = DateTime.now().toUtc();
    expect(ReviewPrompt.due(store, updated), isFalse);
    expect(ReviewPrompt.due(store, updated.add(const Duration(days: 31))), isTrue);
  });
}
