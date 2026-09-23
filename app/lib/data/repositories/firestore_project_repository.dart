import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/result.dart';
import '../../domain/models/credit_block.dart';
import '../../domain/models/project.dart';
import '../sources/firestore_failures.dart';
import 'project_repository.dart';

/// Cloud Firestore implementation, scoped to one signed-in account.
///
/// Documents live at `users/{uid}/projects/{projectId}` — a per-user
/// subcollection rather than a top-level collection filtered by owner, so the
/// security rule is a path match (`request.auth.uid == uid`) that cannot be
/// bypassed by a crafted query, and listing never needs a composite index.
///
/// Offline is not special-cased anywhere in here: Firestore's local cache
/// serves reads and queues writes while the device is offline, which is why
/// this repository has no queue of its own.
class FirestoreProjectRepository implements ProjectRepository {
  /// Fields stored as Firestore [Timestamp]s rather than the epoch integers
  /// the canonical JSON uses, so they sort and read properly in the console
  /// and in queries. Converted at this boundary only — the domain model stays
  /// free of Firestore types.
  static const _timestampFields = ['createdAt', 'updatedAt'];

  final FirebaseFirestore _firestore;
  final String uid;

  FirestoreProjectRepository(this._firestore, {required this.uid});

  CollectionReference<Map<String, dynamic>> get _projects =>
      _firestore.collection('users').doc(uid).collection('projects');

  @override
  Future<Result<List<ProjectSummary>>> listSummaries() {
    return _guard(() async {
      // Firestore's client SDKs have no field projection, so this reads whole
      // documents. Fine while documents are small; if they grow, the summary
      // fields get denormalised into a sibling collection rather than paying
      // for every block on every library render.
      final snapshot = await _projects.orderBy('updatedAt', descending: true).get();
      final summaries = <ProjectSummary>[];
      for (final doc in snapshot.docs) {
        try {
          summaries.add(_fromFirestore(doc.data(), doc.id).summary);
        } on Object {
          // A document this build can't read is skipped so it can't take the
          // whole library down; opening it directly still surfaces the error.
          continue;
        }
      }
      return summaries;
    });
  }

  @override
  Future<Result<Project>> load(String id) {
    return _guard(() async {
      final doc = await _projects.doc(id).get();
      final data = doc.data();
      if (!doc.exists || data == null) throw const _NotFound();
      return _fromFirestore(data, doc.id);
    });
  }

  @override
  Future<Result<Project>> save(Project project) {
    return _guard(() async {
      final owned = project.ownerId == uid ? project : project.copyWith(ownerId: uid);
      await _projects.doc(owned.id).set(_toFirestore(owned));
      return owned;
    });
  }

  @override
  Future<Result<void>> delete(String id) => _guard(() => _projects.doc(id).delete());

  Map<String, Object?> _toFirestore(Project project) {
    final json = project.toJson();
    for (final field in _timestampFields) {
      final millis = json[field];
      if (millis is int) {
        json[field] = Timestamp.fromMillisecondsSinceEpoch(millis);
      }
    }
    return json;
  }

  Project _fromFirestore(Map<String, Object?> data, String documentId) {
    final json = Map<String, Object?>.of(data);
    for (final field in _timestampFields) {
      final value = json[field];
      if (value is Timestamp) json[field] = value.millisecondsSinceEpoch;
    }
    // The document id is authoritative — it is the thing the path was built
    // from, so a mismatched `id` field can't send a later save elsewhere.
    json['id'] = documentId;
    return Project.fromJson(json);
  }

  Future<Result<T>> _guard<T>(Future<T> Function() body) async {
    try {
      return Ok(await body());
    } on _NotFound {
      return const Err(AppFailure.notFound('That project no longer exists.'));
    } on UnsupportedSchemaVersionException catch (e, s) {
      return Err(AppFailure(
        FailureKind.serialization,
        'This project was made with a newer version of EndCrawl.',
        cause: e,
        stackTrace: s,
      ));
    } on UnknownDocumentTypeException catch (e, s) {
      return Err(AppFailure(
        FailureKind.serialization,
        'This project contains a block this version does not understand.',
        cause: e,
        stackTrace: s,
      ));
    } on FirebaseException catch (e, s) {
      return Err(firestoreFailure(e, s));
    } on Object catch (e, s) {
      return Err(AppFailure(FailureKind.unknown, 'Something went wrong. Try again.', cause: e, stackTrace: s));
    }
  }
}

class _NotFound implements Exception {
  const _NotFound();
}

/// Stands in for [FirestoreProjectRepository] when nobody is signed in.
///
/// The UI is gated behind authentication, so this should be unreachable — it
/// exists so an ordering bug surfaces as a handled failure rather than a
/// crash or, worse, a write to the wrong path.
class SignedOutProjectRepository implements ProjectRepository {
  const SignedOutProjectRepository();

  static const _failure = AppFailure(FailureKind.permission, 'Sign in to open your projects.');

  @override
  Future<Result<List<ProjectSummary>>> listSummaries() async => const Err(_failure);

  @override
  Future<Result<Project>> load(String id) async => const Err(_failure);

  @override
  Future<Result<Project>> save(Project project) async => const Err(_failure);

  @override
  Future<Result<void>> delete(String id) async => const Err(_failure);
}
