import 'dart:io';
import 'dart:ui' as ui;

import 'package:archive/archive_io.dart';
import 'package:path/path.dart' as p;

import '../models/export_models.dart';
import 'video_encoder.dart';

/// A PNG per frame, with alpha, streamed into one uncompressed .zip —
/// "title_000001.png" onwards, the numbering editors import as a sequence.
/// PNG is already compressed, so the zip only stores.
class PngSequenceEncoder implements VideoEncoder {
  const PngSequenceEncoder();

  @override
  Future<EncoderCapabilities> capabilities() async => const EncoderCapabilities({Codec.png: 8192});

  @override
  Future<EncodeSession> start(EncodeSpec spec) async {
    final stale = File(spec.outputPath);
    if (await stale.exists()) await stale.delete();
    final zip = ZipFileEncoder()..create(spec.outputPath, level: ZipFileEncoder.store);
    return _PngSession(zip, spec.outputPath, p.basenameWithoutExtension(spec.outputPath));
  }
}

class _PngSession implements EncodeSession {
  final ZipFileEncoder _zip;
  final String _path;
  final String _stem;
  bool _closed = false;

  _PngSession(this._zip, this._path, this._stem);

  @override
  Future<void> append(ui.Image frame, int index) async {
    final png = await frame.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) throw const EncoderException(EncoderFailureKind.failed, 'A frame couldn’t be encoded.');
    final bytes = png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    try {
      _zip.addArchiveFile(ArchiveFile.noCompress('${_stem}_${(index + 1).toString().padLeft(6, '0')}.png', bytes.length, bytes));
    } on FileSystemException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<EncodedFile> finish() async {
    try {
      await _close();
      return EncodedFile(_path, await File(_path).length());
    } on FileSystemException catch (e) {
      throw _failure(e);
    }
  }

  @override
  Future<void> cancel() async {
    try {
      await _close();
    } on FileSystemException {
      // Deleting it below is all that's left to do.
    }
    final file = File(_path);
    if (await file.exists()) await file.delete();
  }

  Future<void> _close() async {
    if (_closed) return;
    _closed = true;
    await _zip.close();
  }

  /// ENOSPC on Linux/Android (28) and Darwin (28 too).
  static EncoderException _failure(FileSystemException e) => e.osError?.errorCode == 28
      ? const EncoderException.outOfSpace()
      : EncoderException(EncoderFailureKind.failed, e.message);
}
