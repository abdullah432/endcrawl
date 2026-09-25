import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/data/sources/session_store.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_project_repository.dart';

void main() {
  late ProviderContainer container;
  late ProjectController controller;

  List<String> ids() => container.read(projectControllerProvider).blocks.map((b) => b.id).toList();

  setUp(() {
    container = ProviderContainer(overrides: [
      projectRepositoryProvider.overrideWithValue(FakeProjectRepository()),
      sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
    ]);
    controller = container.read(projectControllerProvider.notifier);
    for (final id in ['a', 'b', 'c']) {
      controller.addBlock(NameListBlock(id: id, header: id));
    }
  });

  tearDown(() => container.dispose());

  test('insertBlock goes after the given block, or at the end', () {
    controller.insertBlock(const SpacerBlock(id: 'x'), afterId: 'a');
    controller.insertBlock(const SpacerBlock(id: 'y'));
    controller.insertBlock(const SpacerBlock(id: 'z'), afterId: 'gone');
    expect(ids(), ['a', 'x', 'b', 'c', 'y', 'z']);
  });

  test('restoreBlock puts a removed block back where it was, even after other edits', () {
    final removed = controller.deleteBlock('b')!;
    controller.addBlock(const SpacerBlock(id: 'later'));

    controller.restoreBlock(removed, 1);

    expect(ids(), ['a', 'b', 'c', 'later']);
  });

  test('typing into one field is one undo step', () {
    for (final s in ['D', 'Di', 'Dir']) {
      controller.patchBlock('a', (b) => (b as NameListBlock).copyWith(header: s), field: 'header');
    }
    expect((container.read(projectControllerProvider).blocks.first as NameListBlock).header, 'Dir');

    controller.undo();
    expect((container.read(projectControllerProvider).blocks.first as NameListBlock).header, 'a');
  });

  test('bulk mute mutes the selection, then unmutes it when all are muted', () {
    controller.bulkMute({'a', 'b'});
    expect(container.read(projectControllerProvider).blocks.where((b) => b.muted).length, 2);

    controller.bulkMute({'a', 'b'});
    expect(container.read(projectControllerProvider).blocks.where((b) => b.muted), isEmpty);
  });

  test('restyle only touches blocks that have the style', () {
    controller.addBlock(const PairListBlock(id: 'cast'));
    controller.restyle({'a', 'cast'}, leader: LeaderStyle.rule);

    final blocks = container.read(projectControllerProvider).blocks;
    expect((blocks.last as PairListBlock).leader, LeaderStyle.rule);
    expect((blocks.first as NameListBlock).columns, const NameListBlock(id: 'a').columns);
  });
}
