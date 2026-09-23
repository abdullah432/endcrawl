import 'package:cloud_firestore/cloud_firestore.dart';

import '../../core/result.dart';
import '../../domain/models/user_profile.dart';
import '../sources/firestore_failures.dart';

/// Reads and writes the signed-in account's [UserProfile].
abstract interface class UserProfileRepository {
  /// The profile, live. A missing document is the default profile — a new
  /// account has written nothing yet and should still get sensible settings.
  Stream<UserProfile> watch();

  Future<Result<void>> save(UserProfile profile);

  Future<Result<void>> delete();
}

/// `users/{uid}` in Firestore.
class FirestoreUserProfileRepository implements UserProfileRepository {
  final FirebaseFirestore _firestore;
  final String uid;

  FirestoreUserProfileRepository(this._firestore, {required this.uid});

  DocumentReference<Map<String, dynamic>> get _doc => _firestore.collection('users').doc(uid);

  @override
  Stream<UserProfile> watch() => _doc.snapshots().map((snap) {
        final data = snap.data();
        return data == null ? const UserProfile() : UserProfile.fromJson(data);
      });

  @override
  Future<Result<void>> save(UserProfile profile) => _guard(
        () => _doc.set({...profile.toJson(), 'updatedAt': FieldValue.serverTimestamp()}),
      );

  @override
  Future<Result<void>> delete() => _guard(_doc.delete);

  Future<Result<void>> _guard(Future<void> Function() body) async {
    try {
      await body();
      return const Ok(null);
    } on FirebaseException catch (e, s) {
      return Err(firestoreFailure(e, s, subject: 'your settings'));
    } on Object catch (e, s) {
      return Err(AppFailure(FailureKind.unknown, 'Could not save your settings.', cause: e, stackTrace: s));
    }
  }
}

/// Stands in when nobody is signed in: defaults to read, nothing to write.
class SignedOutUserProfileRepository implements UserProfileRepository {
  const SignedOutUserProfileRepository();

  static const _failure = AppFailure(FailureKind.permission, 'Sign in to change your settings.');

  @override
  Stream<UserProfile> watch() => Stream.value(const UserProfile());

  @override
  Future<Result<void>> save(UserProfile profile) async => const Err(_failure);

  @override
  Future<Result<void>> delete() async => const Err(_failure);
}
