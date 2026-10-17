import 'package:lastreel/features/review/data/feedback_repository.dart';

/// Records what the rating prompt would have sent to the team.
class FakeFeedbackRepository implements FeedbackRepository {
  final List<RatingFeedback> sent = [];

  @override
  void submit(RatingFeedback feedback) => sent.add(feedback);
}
