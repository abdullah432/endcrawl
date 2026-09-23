import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/result.dart';

/// Translates a Firestore error into an [AppFailure] a person can read.
///
/// Shared by every Firestore repository so the offline and permission
/// wording is the same wherever it appears. [subject] names the thing being
/// read or written ("that project", "your settings").
AppFailure firestoreFailure(FirebaseException e, StackTrace s, {String subject = 'that project'}) {
  final (kind, message) = switch (e.code) {
    'permission-denied' => (FailureKind.permission, 'You do not have access to $subject.'),
    'not-found' => (FailureKind.notFound, '${_capitalise(subject)} no longer exists.'),
    // `unavailable` normally means offline. Reads are served from cache and
    // writes are queued, so seeing this at all means something the cache
    // could not answer.
    'unavailable' => (FailureKind.network, 'You are offline — this will sync when you reconnect.'),
    'deadline-exceeded' => (FailureKind.network, 'The network is slow right now. Try again.'),
    'resource-exhausted' => (FailureKind.storage, '${_capitalise(subject)} is too large to save.'),
    'unauthenticated' => (FailureKind.permission, 'Your session expired. Sign in again.'),
    _ => (FailureKind.unknown, 'Could not reach $subject. Try again.'),
  };
  return AppFailure(kind, message, cause: e, stackTrace: s);
}

String _capitalise(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
