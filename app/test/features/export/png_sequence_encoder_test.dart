import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:endcrawl/features/export/data/png_sequence_encoder.dart';
import 'package:endcrawl/features/export/data/video_encoder.dart';
import 'package:endcrawl/features/export/models/export_models.dart';
import 'package:flutter_test/flutter_test.dart';

ui.Image _frame(int shade) {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawRect(const ui.Rect.fromLTWH(0, 0, 4, 2), ui.Paint()..color = ui.Color.fromARGB(255, shade, shade, shade));
  return recorder.endRecording().toImageSync(4, 2);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;

  setUp(() async => dir = await Directory.systemTemp.createTemp('png-seq'));
  tearDown(() => dir.delete(recursive: true));

  EncodeSpec spec(String name) => EncodeSpec(
        codec: Codec.png,
        width: 4,
        height: 2,
        fps: 24,
        bitsPerSecond: 0,
        outputPath: '${dir.path}/$name',
      );

  test('writes one numbered PNG per frame into a zip, and reports its size', () async {
    final session = await const PngSequenceEncoder().start(spec('Salt Flats.zip'));
    for (var i = 0; i < 3; i++) {
      final image = _frame(i * 60);
      await session.append(image, i);
      image.dispose();
    }
    final out = await session.finish();

    expect(out.bytes, await File(out.path).length());
    final archive = ZipDecoder().decodeBytes(await File(out.path).readAsBytes());
    expect(archive.files.map((f) => f.name), ['Salt Flats_000001.png', 'Salt Flats_000002.png', 'Salt Flats_000003.png']);
    // Each entry is a real PNG.
    expect(archive.files.first.content.sublist(1, 4), 'PNG'.codeUnits);
  });

  test('cancel removes the partial file, and a new render replaces an old one', () async {
    final first = await const PngSequenceEncoder().start(spec('a.zip'));
    final image = _frame(10);
    await first.append(image, 0);
    await first.cancel();
    expect(File('${dir.path}/a.zip').existsSync(), isFalse);

    File('${dir.path}/b.zip').writeAsStringSync('stale');
    final second = await const PngSequenceEncoder().start(spec('b.zip'));
    await second.append(image, 0);
    image.dispose();
    final out = await second.finish();
    expect(ZipDecoder().decodeBytes(await File(out.path).readAsBytes()).files, hasLength(1));
  });
}
