import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:endcrawl/core/result.dart';
import 'package:endcrawl/data/repositories/firestore_project_repository.dart';
import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/project.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const uid = 'user-1';
  late FakeFirebaseFirestore firestore;
  late FirestoreProjectRepository repository;

  setUp(() {
    firestore = FakeFirebaseFirestore();
    repository = FirestoreProjectRepository(firestore, uid: uid);
  });

  Project sample({String title = 'UNTITLED', DateTime? updatedAt}) {
    final project = Project.create(
      title: title,
      blocks: const [
        TitleBlock(id: 'b1', title: 'THE LONG WAY DOWN'),
        PairListBlock(id: 'b2', rows: [PairCastRow(role: 'ELENA MARSH', actor: 'Priya Raghunathan')]),
      ],
    );
    return updatedAt == null ? project : project.copyWith(updatedAt: updatedAt);
  }

  CollectionReference<Map<String, dynamic>> projectsOf(String owner) =>
      firestore.collection('users').doc(owner).collection('projects');

  /// A document shaped the way the repository writes them — timestamps as
  /// `Timestamp`, not epoch integers. Tests that plant a document directly
  /// have to match that, or `orderBy('updatedAt')` compares an int against a
  /// Timestamp and the whole query fails.
  Map<String, Object?> firestoreDoc(Project project) {
    final json = project.toJson();
    for (final field in ['createdAt', 'updatedAt']) {
      json[field] = Timestamp.fromMillisecondsSinceEpoch(json[field]! as int);
    }
    return json;
  }

  group('FirestoreProjectRepository', () {
    test('writes to users/{uid}/projects/{id}', () async {
      final project = sample(title: 'MY FILM');

      expect((await repository.save(project)).isOk, isTrue);

      final doc = await projectsOf(uid).doc(project.id).get();
      expect(doc.exists, isTrue);
      expect(doc.data()!['title'], 'MY FILM');
    });

    test('stamps the owning uid on save', () async {
      final project = sample();
      expect(project.ownerId, isNull);

      final saved = (await repository.save(project)).valueOrNull!;

      expect(saved.ownerId, uid);
      final doc = await projectsOf(uid).doc(project.id).get();
      expect(doc.data()!['ownerId'], uid);
    });

    test('stores timestamps as Firestore Timestamps, not epoch integers', () async {
      // So they sort and read correctly in queries and in the console; the
      // domain model keeps using DateTime either way.
      final project = sample();
      await repository.save(project);

      final data = (await projectsOf(uid).doc(project.id).get()).data()!;

      expect(data['createdAt'], isA<Timestamp>());
      expect(data['updatedAt'], isA<Timestamp>());
      expect((data['updatedAt']! as Timestamp).toDate().toUtc(), project.updatedAt);
    });

    test('round-trips a project through Firestore', () async {
      final project = sample(title: 'ROUND TRIP');
      await repository.save(project);

      final loaded = (await repository.load(project.id)).valueOrNull!;

      expect(loaded.title, 'ROUND TRIP');
      expect(loaded.createdAt, project.createdAt);
      expect(loaded.updatedAt, project.updatedAt);
      expect(loaded.blocks, hasLength(2));
      expect(loaded.blocks[0], isA<TitleBlock>());
      final cast = loaded.blocks[1] as PairListBlock;
      expect((cast.rows.single as PairCastRow).actor, 'Priya Raghunathan');
    });

    test('lists summaries newest first', () async {
      await repository.save(sample(title: 'OLDER', updatedAt: DateTime.utc(2026, 1, 1)));
      await repository.save(sample(title: 'NEWER', updatedAt: DateTime.utc(2026, 5, 1)));

      final summaries = (await repository.listSummaries()).valueOrNull!;

      expect(summaries.map((s) => s.title).toList(), ['NEWER', 'OLDER']);
    });

    test('only sees the signed-in account\'s projects', () async {
      // The uid is a path segment, not a query filter, so another account's
      // documents are not merely filtered out — they are unreachable.
      await projectsOf('someone-else').doc('TheirProjectAAAAAAAA').set(
            firestoreDoc(sample(title: 'NOT MINE')),
          );
      await repository.save(sample(title: 'MINE'));

      final summaries = (await repository.listSummaries()).valueOrNull!;

      expect(summaries.map((s) => s.title).toList(), ['MINE']);
      expect((await repository.load('TheirProjectAAAAAAAA')).failureOrNull?.kind, FailureKind.notFound);
    });

    test('reports a missing project as notFound', () async {
      expect(
        (await repository.load('DoesNotExistAAAAAAAA')).failureOrNull?.kind,
        FailureKind.notFound,
      );
    });

    test('deletes a project', () async {
      final project = sample();
      await repository.save(project);

      expect((await repository.delete(project.id)).isOk, isTrue);
      expect((await repository.listSummaries()).valueOrNull, isEmpty);
    });

    test('trusts the document id over a mismatched id field', () async {
      // A stale or tampered `id` field must not be able to redirect the next
      // save to a different document.
      final json = firestoreDoc(sample())..['id'] = 'SomeOtherIdAAAAAAAAA';
      await projectsOf(uid).doc('TheRealIdAAAAAAAAAAA').set(json);

      final loaded = (await repository.load('TheRealIdAAAAAAAAAAA')).valueOrNull!;

      expect(loaded.id, 'TheRealIdAAAAAAAAAAA');
    });

    test('one unreadable document does not take down the whole library', () async {
      await repository.save(sample(title: 'GOOD'));
      final broken = firestoreDoc(sample(title: 'BROKEN'));
      (broken['blocks']! as List).add({'type': 'hologram', 'id': 'bX'});
      await projectsOf(uid).doc('BrokenAAAAAAAAAAAAAA').set(broken);

      final summaries = (await repository.listSummaries()).valueOrNull!;

      expect(summaries.map((s) => s.title).toList(), ['GOOD']);
    });

    test('surfaces an unreadable document as a serialization failure on open', () async {
      final broken = firestoreDoc(sample());
      (broken['blocks']! as List).add({'type': 'hologram', 'id': 'bX'});
      await projectsOf(uid).doc('BrokenAAAAAAAAAAAAAA').set(broken);

      expect(
        (await repository.load('BrokenAAAAAAAAAAAAAA')).failureOrNull?.kind,
        FailureKind.serialization,
      );
    });

    test('surfaces a newer schema version as a serialization failure', () async {
      final json = firestoreDoc(sample())..['schemaVersion'] = Project.currentSchemaVersion + 1;
      await projectsOf(uid).doc('FutureAAAAAAAAAAAAAA').set(json);

      expect(
        (await repository.load('FutureAAAAAAAAAAAAAA')).failureOrNull?.kind,
        FailureKind.serialization,
      );
    });

    test('preserves settings through Firestore', () async {
      final project = sample().copyWith(
        settings: const ProjectSettings(formatId: '9x16', fps: 30, look: RollLook.crawl3d, tilt: 33),
      );
      await repository.save(project);

      final loaded = (await repository.load(project.id)).valueOrNull!;

      expect(loaded.settings.formatId, '9x16');
      expect(loaded.settings.fps, 30);
      expect(loaded.settings.look, RollLook.crawl3d);
      expect(loaded.settings.tilt, 33);
    });
  });

  group('SignedOutProjectRepository', () {
    test('fails every call with a permission failure rather than crashing', () async {
      const signedOut = SignedOutProjectRepository();

      expect((await signedOut.listSummaries()).failureOrNull?.kind, FailureKind.permission);
      expect((await signedOut.load('x')).failureOrNull?.kind, FailureKind.permission);
      expect((await signedOut.save(Project.create())).failureOrNull?.kind, FailureKind.permission);
      expect((await signedOut.delete('x')).failureOrNull?.kind, FailureKind.permission);
    });
  });
}
