import 'dart:ui' as ui;

import '../models/export_models.dart';

/// What to encode: the codec, the picture, and where the file goes.
class EncodeSpec {
  final Codec codec;
  final int width;
  final int height;
  final double fps;

  /// Target bit rate, for the codecs that take one (H.264, HEVC).
  final int bitsPerSecond;

  /// The file to write, replacing any earlier render of the same name; its
  /// extension matches [Codec.extension].
  final String outputPath;

  const EncodeSpec({
    required this.codec,
    required this.width,
    required this.height,
    required this.fps,
    required this.bitsPerSecond,
    required this.outputPath,
  });

  /// The frame rate as a fraction, so NTSC rates stay exact: 23.976 is
  /// 24000/1001, and a frame's time is `index × den / num` seconds.
  (int num, int den) get rate => frameRateFraction(fps);
}

/// The codecs this device can make, and the longest edge each can take.
class EncoderCapabilities {
  final Map<Codec, int> maxEdge;

  /// Free space where renders are written, in bytes; null when unknown.
  final int? freeBytes;

  const EncoderCapabilities(this.maxEdge, {this.freeBytes});

  bool supports(Codec codec) => maxEdge.containsKey(codec);

  Iterable<Codec> get codecs => Codec.values.where(supports);

  /// The output sizes [codec] can be made at here.
  Iterable<ExportResolution> resolutionsFor(Codec codec) =>
      ExportResolution.values.where((r) => (maxEdge[codec] ?? 0) >= r.edge);
}

/// Turns rendered frames into a file. Implemented natively for video
/// (AVFoundation, MediaCodec) and in Dart for image sequences.
abstract interface class VideoEncoder {
  Future<EncoderCapabilities> capabilities();

  Future<EncodeSession> start(EncodeSpec spec);
}

/// One file being written. Frames go in order, each finished before the
/// next is sent, which is the back-pressure: the render never gets ahead
/// of the encoder by more than a frame.
abstract interface class EncodeSession {
  /// Adds frame [index]. The caller still owns [frame] and disposes it.
  Future<void> append(ui.Image frame, int index);

  /// Closes the file and says where it is and how big it came out.
  Future<EncodedFile> finish();

  /// Stops and removes the partial file.
  Future<void> cancel();
}

/// A finished render on disk.
class EncodedFile {
  final String path;
  final int bytes;
  const EncodedFile(this.path, this.bytes);
}

/// Why an encode stopped, in words the failed screen (6.3) can show.
class EncoderException implements Exception {
  final EncoderFailureKind kind;
  final String message;

  const EncoderException(this.kind, this.message);

  const EncoderException.outOfSpace() : this(EncoderFailureKind.outOfSpace, 'Not enough free space.');

  @override
  String toString() => 'EncoderException($kind): $message';
}

/// PNG sequences are made in Dart; everything else by the platform.
class RoutingVideoEncoder implements VideoEncoder {
  final VideoEncoder video;
  final VideoEncoder images;

  const RoutingVideoEncoder({required this.video, required this.images});

  @override
  Future<EncoderCapabilities> capabilities() async {
    final (v, i) = await (video.capabilities(), images.capabilities()).wait;
    return EncoderCapabilities({...v.maxEdge, ...i.maxEdge}, freeBytes: v.freeBytes ?? i.freeBytes);
  }

  @override
  Future<EncodeSession> start(EncodeSpec spec) =>
      spec.codec == Codec.png ? images.start(spec) : video.start(spec);
}
