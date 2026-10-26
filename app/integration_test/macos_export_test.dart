import 'dart:io';

import 'package:archive/archive_io.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lastreel/domain/engine/roll_engine.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/credit_face.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/features/export/data/native_video_encoder.dart';
import 'package:lastreel/features/export/data/png_sequence_encoder.dart';
import 'package:lastreel/features/export/data/video_encoder.dart';
import 'package:lastreel/features/export/models/export_models.dart';
import 'package:lastreel/features/export/render/frame_renderer.dart';

/// Native smoke test: real LastReel frames, shared AVFoundation encoder,
/// rational timing, PNG output and cancellation. No account or Photos writes.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'macOS renders its supported formats and cleans cancellation',
    (tester) async {
      expect(Platform.isMacOS, isTrue);
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Center(child: Text('Checking LastReel desktop exports…')),
          ),
        ),
      );
      await tester.runAsync(() async {
        const encoder = RoutingVideoEncoder(
          video: NativeVideoEncoder(),
          images: PngSequenceEncoder(),
        );
        final caps = await encoder.capabilities();
        expect(caps.supports(Codec.h264), isTrue);
        final directory = await Directory.systemTemp.createTemp(
          'lastreel-macos-qa-',
        );
        for (final codec in caps.codecs) {
          final settings = ProjectSettings(
            fps: codec == Codec.hevc ? 29.97 : 24,
            mode: TimingMode.duration,
            durationFrames: 12,
            headSeconds: 0,
            tailSeconds: 0,
            background: codec == Codec.prores4444 || codec == Codec.png
                ? MonitorBackground.alpha
                : MonitorBackground.black,
          );
          final source = await FrameRenderer.open(
            settings: settings,
            blocks: const [
              TitleBlock(
                id: 'title',
                title: 'LASTREEL ON MAC',
                byline: 'COOKOO',
              ),
            ],
            geometry: computeGeometry(
              formatW: 1920,
              formatH: 1080,
              face: CreditFace.grotesque,
            ),
            outputWidth: 640,
            outputHeight: 360,
          );
          final spec = EncodeSpec(
            codec: codec,
            width: 640,
            height: 360,
            fps: settings.fps,
            bitsPerSecond: bitsPerSecond(codec, 640, 360),
            outputPath: '${directory.path}/${codec.name}.${codec.extension}',
          );
          EncodeSession? session;
          try {
            session = await encoder.start(spec);
            for (var index = 0; index < source.frameCount; index++) {
              final image = await source.render(index);
              try {
                await session.append(image, index);
              } finally {
                image.dispose();
              }
            }
            final result = await session.finish();
            session = null;
            expect(result.bytes, greaterThan(100));
            expect(await File(result.path).length(), result.bytes);
            if (codec == Codec.png) {
              final archive = ZipDecoder().decodeBytes(
                await File(result.path).readAsBytes(),
              );
              expect(archive.files, hasLength(source.frameCount));
              expect(archive.files.first.name, 'png_000001.png');
              expect(
                archive.files.last.name,
                'png_${source.frameCount.toString().padLeft(6, '0')}.png',
              );
            } else {
              final header = await File(result.path).openRead(0, 12).first;
              expect(header.sublist(4, 8), 'ftyp'.codeUnits);
            }
            debugPrint(
              'LASTREEL_MAC_EXPORT:${codec.name}:${source.frameCount}:${spec.rate}:${result.path}',
            );
          } finally {
            await session?.cancel();
            source.dispose();
          }
        }
        final cancelled = '${directory.path}/cancelled.mp4';
        final session = await encoder.start(
          EncodeSpec(
            codec: Codec.h264,
            width: 640,
            height: 360,
            fps: 24,
            bitsPerSecond: 2000000,
            outputPath: cancelled,
          ),
        );
        await session.cancel();
        expect(await File(cancelled).exists(), isFalse);
      });
    },
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
