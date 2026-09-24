import 'dart:ui' as ui;

import 'package:endcrawl/features/export/data/native_video_encoder.dart';
import 'package:endcrawl/features/export/data/video_encoder.dart';
import 'package:endcrawl/features/export/models/export_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The contract the iOS (VideoEncoderPlugin.swift) and Android
/// (VideoEncoderPlugin.kt) sides implement.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final calls = <MethodCall>[];
  Object? Function(MethodCall call) reply = (_) => null;

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      NativeVideoEncoder.channel,
      (call) async {
        calls.add(call);
        return reply(call);
      },
    );
  });

  tearDown(() => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(NativeVideoEncoder.channel, null));

  test('capabilities: codecs by name with their longest edge, and free space', () async {
    reply = (_) => {
          'codecs': {'h264': 3840, 'hevc': 1920, 'nonsense': 1},
          'freeBytes': 5000000000,
        };
    final caps = await const NativeVideoEncoder().capabilities();
    expect(caps.maxEdge, {Codec.h264: 3840, Codec.hevc: 1920});
    expect(caps.freeBytes, 5000000000);
  });

  test('a session starts, takes RGBA frames with their index, and finishes with the file', () async {
    reply = (call) => switch (call.method) {
          'start' => 7,
          'finish' => {'path': '/r/x.mov', 'bytes': 1234},
          _ => null,
        };
    final session = await const NativeVideoEncoder().start(const EncodeSpec(
      codec: Codec.prores4444,
      width: 4,
      height: 2,
      fps: 23.976,
      bitsPerSecond: 0,
      outputPath: '/r/x.mov',
    ));

    final recorder = ui.PictureRecorder();
    ui.Canvas(recorder).drawPaint(ui.Paint()..color = const ui.Color(0xFFFFFFFF));
    final image = recorder.endRecording().toImageSync(4, 2);
    await session.append(image, 3);
    image.dispose();
    final out = await session.finish();

    expect(calls.first.arguments, {
      'codec': 'prores4444',
      'width': 4,
      'height': 2,
      'fpsNum': 24000,
      'fpsDen': 1001,
      'bitrate': 0,
      'path': '/r/x.mov',
    });
    final append = calls[1].arguments as Map;
    expect((append['id'], append['frame'], append['width'], append['height']), (7, 3, 4, 2));
    expect((append['rgba'] as Uint8List).length, 4 * 2 * 4);
    expect((out.path, out.bytes), ('/r/x.mov', 1234));
  });

  test('platform errors become the causes 6.3 shows', () async {
    reply = (call) => throw PlatformException(code: call.method == 'start' ? 'out_of_space' : 'failed');
    await expectLater(
      const NativeVideoEncoder().start(const EncodeSpec(
        codec: Codec.h264,
        width: 2,
        height: 2,
        fps: 24,
        bitsPerSecond: 1,
        outputPath: '/r/y.mp4',
      )),
      throwsA(isA<EncoderException>().having((e) => e.kind, 'kind', EncoderFailureKind.outOfSpace)),
    );
  });

  test('without the plugin there are simply no video codecs', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(NativeVideoEncoder.channel, null);
    expect((await const NativeVideoEncoder().capabilities()).maxEdge, isEmpty);
  });
}
