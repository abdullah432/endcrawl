// The Firestore SDK's sealed references are mocked only to deliver stream
// errors; FakeFirebaseFirestore cannot simulate these listener errors.
// ignore_for_file: subtype_of_sealed_class

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/features/tester/tester_mode.dart';

class _Firestore extends Fake implements FirebaseFirestore {
  final Stream<DocumentSnapshot<Map<String, dynamic>>> stream;
  _Firestore(this.stream);
  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      _Collection(stream);
}

class _Collection extends Fake
    implements CollectionReference<Map<String, dynamic>> {
  final Stream<DocumentSnapshot<Map<String, dynamic>>> stream;
  _Collection(this.stream);
  @override
  DocumentReference<Map<String, dynamic>> doc([String? path]) =>
      _Document(stream);
}

class _Document extends Fake
    implements DocumentReference<Map<String, dynamic>> {
  final Stream<DocumentSnapshot<Map<String, dynamic>>> stream;
  _Document(this.stream);
  @override
  Stream<DocumentSnapshot<Map<String, dynamic>>> snapshots({
    bool includeMetadataChanges = false,
    ListenSource source = ListenSource.defaultSource,
  }) => stream;
}

void main() {
  test(
    'a denied tester check resolves to false instead of leaving the desk invite waiting',
    () async {
      final container = ProviderContainer(
        overrides: [
          currentUidProvider.overrideWithValue('user'),
          firestoreProvider.overrideWithValue(
            _Firestore(
              Stream.error(
                FirebaseException(
                  plugin: 'cloud_firestore',
                  code: 'permission-denied',
                ),
              ),
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(testerAllowedProvider, (_, _) {});
      expect(await container.read(testerAllowedProvider.future), isFalse);
      expect(container.read(testerAllowedProvider).isLoading, isFalse);
    },
  );

  test('an error after a tester grant removes the device override', () async {
    final db = FakeFirebaseFirestore();
    await db.doc('testers/user').set({'enabled': true});
    final snapshot = await db.doc('testers/user').get();
    final stream = StreamController<DocumentSnapshot<Map<String, dynamic>>>();
    addTearDown(stream.close);
    final container = ProviderContainer(
      overrides: [
        currentUidProvider.overrideWithValue('user'),
        firestoreProvider.overrideWithValue(_Firestore(stream.stream)),
        testerStoreProvider.overrideWithValue(InMemoryTesterStore(proOn: true)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(testerProProvider, (_, _) {});
    stream.add(snapshot);
    expect(await container.read(testerAllowedProvider.future), isTrue);
    expect(container.read(testerProProvider), isTrue);
    stream.addError(
      FirebaseException(plugin: 'cloud_firestore', code: 'permission-denied'),
    );
    await Future<void>.delayed(Duration.zero);
    expect(container.read(testerAllowedProvider).requireValue, isFalse);
    expect(container.read(testerProProvider), isFalse);
  });
}
