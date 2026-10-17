import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../bootstrap.dart';
import '../../settings/controllers/settings_controller.dart';

/// What a feedback report can be about (6.2b) — chips, so reports sort.
enum FeedbackTopic {
  exportSpeed('exportSpeed', 'Export speed'),
  timingTools('timingTools', 'Timing tools'),
  templates('templates', 'Templates'),
  ads('ads', 'Ads'),
  crashes('crashes', 'Crashes or bugs'),
  other('other', 'Something else');

  final String wire;
  final String label;
  const FeedbackTopic(this.wire, this.label);
}

/// One answer to the rating prompt: the stars, and for a low rating what
/// to fix. No project content is ever included.
class RatingFeedback {
  final int rating;
  final Set<FeedbackTopic> topics;
  final String message;

  const RatingFeedback({required this.rating, this.topics = const {}, this.message = ''});
}

/// Sends rating feedback privately to the LastReel team. Never to the store.
abstract interface class FeedbackRepository {
  /// Fire and forget: the write is queued (offline too) and never blocks
  /// the person, so this doesn't wait for the server.
  void submit(RatingFeedback feedback);
}

/// `feedback/{id}` in Firestore — create-only for the signed-in account;
/// nobody can read it back from the app (see firestore.rules).
class FirestoreFeedbackRepository implements FeedbackRepository {
  final FirebaseFirestore _firestore;
  final String uid;
  final String? appVersion;

  FirestoreFeedbackRepository(this._firestore, {required this.uid, this.appVersion});

  @override
  void submit(RatingFeedback feedback) {
    _firestore.collection('feedback').add({
      'uid': uid,
      'rating': feedback.rating,
      'topics': [for (final t in feedback.topics) t.wire],
      'message': _clip(feedback.message.trim(), 2000),
      'appVersion': _clip(appVersion ?? '', 64),
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'createdAt': FieldValue.serverTimestamp(),
    }).ignore();
  }
}

/// Signed out there is nobody to attribute feedback to; it is dropped.
class SignedOutFeedbackRepository implements FeedbackRepository {
  const SignedOutFeedbackRepository();

  @override
  void submit(RatingFeedback feedback) {}
}

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const SignedOutFeedbackRepository();
  return FirestoreFeedbackRepository(
    ref.watch(firestoreProvider),
    uid: uid,
    appVersion: ref.watch(appVersionProvider).value,
  );
});

/// Keeps a field within the limit firestore.rules enforces.
String _clip(String s, int max) => s.length <= max ? s : s.substring(0, max);
