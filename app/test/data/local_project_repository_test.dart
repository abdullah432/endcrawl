import 'dart:convert';
import 'dart:io';

import 'package:endcrawl/core/result.dart';
import 'package:endcrawl/data/repositories/local_project_repository.dart';
import 'package:endcrawl/data/sources/project_local_store.dart';
import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/project.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory root;
  late LocalProjectRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('endcrawl_test');
    repository = LocalProjectRepository(ProjectLocalStore(root));
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  Project sample({String title = 'UNTITLED', DateTime? updatedAt}) {
    final project = Project.create(
      title: title,
      blocks: const [TitleBlock(id: 'b1', title: 'THE LONG WAY DOWN')],
    );
    return updatedAt == null ? project : project.copyWith(updatedAt: updatedAt);
  }

  group('LocalProjectRepository', () {
    test('saves and loads a project', () async {
      final project = sample(title: 'MY FILM');

      expect((await repository.save(project)).isOk, isTrue);

      final loaded = await repository.load(project.id);
      expect(loaded, isA<Ok<Project>>());
      expect(loaded.valueOrNull!.title, 'MY FILM');
      expect(loaded.valueOrNull!.blocks.single, isA<TitleBlock>());
    });

    test('reports a missing project as notFound rather than throwing', () async {
      final result = await repository.load('DoesNotExistAAAAAAAA');

      expect(result.failureOrNull?.kind, FailureKind.notFound);
    });

    test('lists summaries newest first', () async {
      await repository.save(sample(title: 'OLDER', updatedAt: DateTime.utc(2026, 1, 1)));
      await repository.save(sample(title: 'NEWER', updatedAt: DateTime.utc(2026, 5, 1)));
      await repository.save(sample(title: 'MIDDLE', updatedAt: DateTime.utc(2026, 3, 1)));

      final summaries = (await repository.listSummaries()).valueOrNull!;

      expect(summaries.map((s) => s.title).toList(), ['NEWER', 'MIDDLE', 'OLDER']);
      expect(summaries.first.blockCount, 1);
    });

    test('deletes a project', () async {
      final project = sample();
      await repository.save(project);

      expect((await repository.delete(project.id)).isOk, isTrue);
      expect((await repository.load(project.id)).failureOrNull?.kind, FailureKind.notFound);
      expect((await repository.listSummaries()).valueOrNull, isEmpty);
    });

    test('round-trips the last-opened project id', () async {
      expect((await repository.readLastOpenedId()).valueOrNull, isNull);

      await repository.writeLastOpenedId('Abc123XyzAbc123XyzQq');
      expect((await repository.readLastOpenedId()).valueOrNull, 'Abc123XyzAbc123XyzQq');

      await repository.writeLastOpenedId(null);
      expect((await repository.readLastOpenedId()).valueOrNull, isNull);
    });

    test('keeps the left-open flag, so a killed session is recoverable', () async {
      final openedAt = DateTime.utc(2026, 4, 1, 12);
      await repository.save(sample().copyWith(openedAt: openedAt));

      final summaries = (await repository.listSummaries()).valueOrNull!;
      expect(summaries.single.wasLeftOpen, isTrue);
    });

    test('a clean close clears the left-open flag', () async {
      final project = sample().copyWith(openedAt: DateTime.utc(2026, 4, 1));
      await repository.save(project);
      await repository.save(project.copyWith(clearOpenedAt: true));

      final summaries = (await repository.listSummaries()).valueOrNull!;
      expect(summaries.single.wasLeftOpen, isFalse);
    });

    test('one corrupt document does not take down the whole library', () async {
      await repository.save(sample(title: 'GOOD'));
      await File('${root.path}/CorruptAAAAAAAAAAAAA.json').writeAsString('{not json');

      final summaries = (await repository.listSummaries()).valueOrNull!;

      expect(summaries.map((s) => s.title).toList(), ['GOOD']);
    });

    test('a document with an unreadable block surfaces a serialization failure on open', () async {
      final json = sample().toJson();
      (json['blocks']! as List).add({'type': 'hologram', 'id': 'bX'});
      final id = json['id']! as String;
      await File('${root.path}/$id.json').writeAsString(jsonEncode(json));

      final result = await repository.load(id);

      expect(result.failureOrNull?.kind, FailureKind.serialization);
    });

    test('a document from a newer schema surfaces a serialization failure on open', () async {
      final json = sample().toJson();
      json['schemaVersion'] = Project.currentSchemaVersion + 1;
      final id = json['id']! as String;
      await File('${root.path}/$id.json').writeAsString(jsonEncode(json));

      expect((await repository.load(id)).failureOrNull?.kind, FailureKind.serialization);
    });

    test('a save leaves no temp file behind', () async {
      await repository.save(sample());

      final names = await root.list().map((e) => e.path.split('/').last).toList();
      expect(names.where((n) => n.endsWith('.tmp')), isEmpty);
    });

    test('refuses a project id that could escape the store directory', () async {
      // Ids are app-minted, but the store must not be the thing that trusts
      // them — a traversal id has to fail rather than address a parent path.
      final result = await repository.load('../../etc/passwd');

      expect(result.failureOrNull?.kind, FailureKind.storage);
    });
  });
}
