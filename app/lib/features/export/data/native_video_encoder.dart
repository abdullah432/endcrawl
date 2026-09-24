import 'dart:ui' as ui;

import 'package:flutter/services.dart';

import '../models/export_models.dart';
import 'video_encoder.dart';

/// Video through the platform's own encoders, over one method channel:
/// AVAssetWriter on iOS (H.264, HEVC, ProRes) and MediaCodec + MediaMuxer
/// on Android (H.264, HEVC). No third-party encoder is bundled.
///
/// Frames cross as premultiplied RGBA; the platform swizzles them into its
/// pixel format and stamps each with its own time, so a paused render
/// resumes without a gap or a duplicate.
class NativeVideoEncoder implements VideoEncoder {
  static const channel = MethodChannel('endcrawl/encoder');

  const NativeVideoEncoder();

  @override
  Future<EncoderCapabilities> capabilities() async {
    try {
      final raw = await channel.invokeMapMethod<String, Object?>('capabilities');
      final codecs = (raw?['codecs'] as Map?) ?? const {};
      return EncoderCapabilities(
        {
          for (final c in Codec.values)
            if (codecs[c.name] case final int maxEdge) c: maxEdge,
        },
        freeBytes: raw?['freeBytes'] as int?,
      );
    } on MissingPluginException {
      // A platform without the encoder (tests, desktop): no video codecs.
      return const EncoderCapabilities({});
    } on PlatformException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<EncodeSession> start(EncodeSpec spec) async {
    final (num, den) = spec.rate;
    try {
      final id = await channel.invokeMethod<int>('start', {
        'codec': spec.codec.name,
        'width': spec.width,
        'height': spec.height,
        'fpsNum': num,
        'fpsDen': den,
        'bitrate': spec.bitsPerSecond,
        'path': spec.outputPath,
      });
      return _NativeSession(id!);
    } on PlatformException catch (e) {
      throw _failure(e);
    }
  }
}

class _NativeSession implements EncodeSession {
  final int _id;
  _NativeSession(this._id);

  @override
  Future<void> append(ui.Image frame, int index) async {
    final data = await frame.toByteData(format: ui.ImageByteFormat.rawRgba);
    if (data == null) throw const EncoderException(EncoderFailureKind.failed, 'A frame couldn’t be read back.');
    await _call('append', {
      'id': _id,
      'frame': index,
      'width': frame.width,
      'height': frame.height,
      'rgba': data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    });
  }

  @override
  Future<EncodedFile> finish() async {
    final out = (await _call('finish', {'id': _id}))! as Map;
    return EncodedFile(out['path'] as String, out['bytes'] as int);
  }

  @override
  Future<void> cancel() async {
    try {
      await NativeVideoEncoder.channel.invokeMethod<void>('cancel', {'id': _id});
    } on PlatformException {
      // Already gone.
    }
  }

  Future<Object?> _call(String method, Map<String, Object?> args) async {
    try {
      return await NativeVideoEncoder.channel.invokeMethod<Object?>(method, args);
    } on PlatformException catch (e) {
      throw _failure(e);
    }
  }
}

/// The platform side reports `out_of_space`, `unsupported` or `failed`.
EncoderException _failure(PlatformException e) => switch (e.code) {
      'out_of_space' => const EncoderException.outOfSpace(),
      'unsupported' => EncoderException(EncoderFailureKind.unsupported, e.message ?? 'This device can’t encode that.'),
      _ => EncoderException(EncoderFailureKind.failed, e.message ?? 'The encoder stopped.'),
    };
