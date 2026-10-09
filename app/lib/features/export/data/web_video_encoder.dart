import 'dart:convert';
import 'dart:js_interop';
import 'dart:ui' as ui;
import '../models/export_models.dart';
import 'browser_bridge.dart';
import 'video_encoder.dart';

/// Implements the native encoder seam using WebCodecs; orchestration is shared.
class NativeVideoEncoder implements VideoEncoder {
  const NativeVideoEncoder();
  @override
  Future<EncoderCapabilities> capabilities() async {
    try {
      final data =
          jsonDecode((await browserCapabilities().toDart).toDart)
              as Map<String, dynamic>;
      Map<Codec, int> map(String key) => {
        for (final c in Codec.values)
          if (data[key][c.name] case final num edge) c: edge.toInt(),
      };
      return EncoderCapabilities(
        map('maxEdge'),
        maxEdgeAt60: map('maxEdgeAt60'),
        freeBytes: (data['freeBytes'] as num?)?.toInt(),
      );
    } catch (_) {
      return const EncoderCapabilities({});
    }
  }

  @override
  Future<EncodeSession> start(EncodeSpec spec) async {
    if (spec.codec != Codec.h264) {
      throw const EncoderException(
        EncoderFailureKind.unsupported,
        'This format is available in the mobile app.',
      );
    }
    final (num, den) = spec.rate;
    try {
      await browserVideoStart(
        spec.outputPath.toJS,
        spec.width.toJS,
        spec.height.toJS,
        num.toJS,
        den.toJS,
        spec.bitsPerSecond.toJS,
      ).toDart;
      return _WebSession(spec.outputPath);
    } catch (error) {
      throw browserEncoderFailure(error);
    }
  }
}

class _WebSession implements EncodeSession {
  final String id;
  _WebSession(this.id);
  @override
  Future<void> append(ui.Image frame, int index) async {
    final data = await frame.toByteData(
      format: ui.ImageByteFormat.rawStraightRgba,
    );
    if (data == null) {
      throw const EncoderException(
        EncoderFailureKind.failed,
        'A frame could not be read.',
      );
    }
    try {
      await browserVideoAppend(
        id.toJS,
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes).toJS,
        index.toJS,
      ).toDart;
    } catch (error) {
      throw browserEncoderFailure(error);
    }
  }

  @override
  Future<EncodedFile> finish() async {
    try {
      return EncodedFile(
        id,
        (await browserVideoFinish(id.toJS).toDart).toDartInt,
      );
    } catch (error) {
      throw browserEncoderFailure(error);
    }
  }

  @override
  Future<void> cancel() async {
    await browserRelease(id.toJS).toDart;
  }
}
