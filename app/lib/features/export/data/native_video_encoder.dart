import 'dart:ui' as ui;
import 'package:cookoo_video_export/cookoo_video_export.dart' as shared;
import '../models/export_models.dart';
import 'video_encoder.dart';

class NativeVideoEncoder implements VideoEncoder {
  static const channel = shared.VideoEncoder.channel;
  const NativeVideoEncoder();
  @override
  Future<EncoderCapabilities> capabilities() async {
    try {
      final caps = await const shared.VideoEncoder().capabilities();
      return EncoderCapabilities(
        {
          for (final entry in caps.maxEdge.entries)
            Codec.values.byName(entry.key.name): entry.value,
        },
        freeBytes: caps.freeBytes,
        maxEdgeAt60: caps.maxEdgeAt60 == null
            ? null
            : {
                for (final entry in caps.maxEdgeAt60!.entries)
                  Codec.values.byName(entry.key.name): entry.value,
              },
      );
    } on shared.VideoExportException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<EncodeSession> start(EncodeSpec spec) async {
    try {
      final (num, den) = spec.rate;
      return _Session(
        await const shared.VideoEncoder().start(
          shared.VideoSpec(
            codec: shared.VideoCodec.values.byName(spec.codec.name),
            width: spec.width,
            height: spec.height,
            fpsNumerator: num,
            fpsDenominator: den,
            bitrate: spec.bitsPerSecond,
            outputPath: spec.outputPath,
          ),
        ),
      );
    } on shared.VideoExportException catch (e) {
      throw _failure(e);
    }
  }
}

class _Session implements EncodeSession {
  _Session(this.session);
  final shared.VideoSession session;
  @override
  Future<void> append(ui.Image image, int index) async {
    try {
      await session.append(image, index);
    } on shared.VideoExportException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<EncodedFile> finish() async {
    try {
      final file = await session.finish();
      return EncodedFile(file.path, file.bytes);
    } on shared.VideoExportException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await session.cancel();
    } on shared.VideoExportException {
      // Preserve the adapter's best-effort cleanup contract.
    }
  }
}

EncoderException _failure(shared.VideoExportException e) => EncoderException(
  e.code == 'out_of_space'
      ? EncoderFailureKind.outOfSpace
      : e.code == 'unsupported'
      ? EncoderFailureKind.unsupported
      : EncoderFailureKind.failed,
  e.message,
);
