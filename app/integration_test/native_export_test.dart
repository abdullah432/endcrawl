import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:lastreel/domain/engine/roll_engine.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/domain/models/credit_face.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/features/export/data/export_destinations.dart';
import 'package:lastreel/features/export/data/native_video_encoder.dart';
import 'package:lastreel/features/export/data/video_encoder.dart';
import 'package:lastreel/features/export/models/export_models.dart';
import 'package:lastreel/features/export/render/frame_renderer.dart';

final _status = ValueNotifier('Preparing Endcrawl export checks…');

/// Real Endcrawl frames, shared native encoder and gallery destination.
/// Run in an isolated QA installation: Flutter's test runner removes its app.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const edge = int.fromEnvironment('EXPORT_EDGE', defaultValue: 1280);
  const height = edge * 9 ~/ 16;
  const resolutionOnly = bool.fromEnvironment('EXPORT_RESOLUTION_ONLY');
  for (final codec in [Codec.h264, Codec.hevc]) {
    testWidgets('${codec.name} $edge credits render and save to the gallery', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: ValueListenableBuilder<String>(
                valueListenable: _status,
                builder: (context, status, child) => Text(
                  '$status\nPlease keep this app open.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ),
      );
      const encoder = NativeVideoEncoder();
      final caps = await encoder.capabilities();
      if (Platform.isAndroid) {
        expect(caps.supports(Codec.prores422), isFalse);
        expect(caps.supports(Codec.prores4444), isFalse);
      }
      if ((caps.maxEdge[codec] ?? 0) < edge) {
        debugPrintSynchronously('ENDCRAWL_UNSUPPORTED:${codec.name}:$edge');
        expect(codec, isNot(Codec.h264));
        return;
      }
      final dir = await Directory.systemTemp.createTemp('endcrawl-export-');
      final settings = ProjectSettings(
        formatId: '16x9',
        fps: codec == Codec.h264 ? 30 : 29.97,
        mode: TimingMode.duration,
        durationFrames: codec == Codec.h264 ? 180 : 91,
        headSeconds: .1,
        tailSeconds: .1,
      );
      final geometry = computeGeometry(
        formatW: 1920,
        formatH: 1080,
        face: CreditFace.grotesque,
      );
      FrameRenderer? source;
      EncodeSession? session;
      try {
        await tester.runAsync(() async {
          source = await FrameRenderer.open(
            settings: settings,
            blocks: const [
              TitleBlock(
                id: 'title',
                title: 'ENDCRAWL EXPORT TEST',
                byline: 'A COOKOO FILM',
              ),
              NameListBlock(
                id: 'direction',
                header: 'Directed by',
                names: ['The shared encoder'],
              ),
              PairListBlock(
                id: 'cast',
                header: 'Cast',
                rows: [
                  PairCastRow(role: 'Renderer', actor: 'Endcrawl'),
                  PairCastRow(role: 'Encoder', actor: 'cookoo_video_export'),
                ],
              ),
              NameListBlock(
                id: 'thanks',
                header: 'Special thanks',
                names: ['Your export device'],
              ),
            ],
            geometry: geometry,
            outputWidth: edge,
            outputHeight: height,
          );
          final spec = EncodeSpec(
            codec: codec,
            width: edge,
            height: height,
            fps: settings.fps,
            bitsPerSecond: bitsPerSecond(codec, edge, height),
            outputPath: '${dir.path}/Endcrawl-device-${codec.name}-$edge.mp4',
          );
          expect(source!.frameCount, settings.durationFrames);
          session = await encoder.start(spec);
          for (var index = 0; index < source!.frameCount; index++) {
            _status.value =
                'Endcrawl ${codec.label} $edge×$height\n'
                'Frame ${index + 1}/${source!.frameCount}';
            if (index % 15 == 0) {
              debugPrintSynchronously(
                'ENDCRAWL_PROGRESS:${codec.name}:$edge:'
                '$index:${source!.frameCount}',
              );
            }
            final image = await source!.render(index);
            try {
              await session!.append(image, index);
            } finally {
              image.dispose();
            }
          }
          final result = await session!.finish();
          session = null;
          expect(result.bytes, greaterThan(1000));
          expect(await File(result.path).length(), result.bytes);
          final saved = await const PlatformExportDestinations().saveToPhotos(
            result.artifact,
          );
          expect(saved.isOk, isTrue, reason: saved.failureOrNull?.toString());
          debugPrintSynchronously(
            'ENDCRAWL_SPEC:${codec.name}:${jsonEncode({'frames': source!.frameCount, 'fpsNum': spec.rate.$1, 'fpsDen': spec.rate.$2, 'width': edge, 'height': height})}',
          );
          final encoded = base64Encode(await File(result.path).readAsBytes());
          for (var i = 0; i < encoded.length; i += 900) {
            debugPrintSynchronously(
              'ENDCRAWL_ARTIFACT:${codec.name}.mp4:$i:'
              '${encoded.substring(i, math.min(i + 900, encoded.length))}',
            );
          }
        });
      } finally {
        await session?.cancel();
        source?.dispose();
        await dir.delete(recursive: true);
      }
      expect(tester.takeException(), isNull);
    }, timeout: const Timeout(Duration(minutes: 30)));
  }

  if (!resolutionOnly) {
    testWidgets('cancellation removes the native partial file', (tester) async {
      final dir = await Directory.systemTemp.createTemp('endcrawl-cancel-');
      final path = '${dir.path}/cancelled.mp4';
      try {
        final session = await const NativeVideoEncoder().start(
          EncodeSpec(
            codec: Codec.h264,
            width: 1280,
            height: 720,
            fps: 30,
            bitsPerSecond: 5000000,
            outputPath: path,
          ),
        );
        await session.cancel();
        expect(await File(path).exists(), isFalse);
      } finally {
        await dir.delete(recursive: true);
      }
    });
  }
}
