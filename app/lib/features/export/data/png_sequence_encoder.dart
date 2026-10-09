import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import '../models/export_models.dart';
import 'output_sink.dart';
import 'video_encoder.dart';

/// One incremental PNG/ZIP encoder for native files and browser storage.
class PngSequenceEncoder implements VideoEncoder {
  const PngSequenceEncoder();
  @override
  Future<EncoderCapabilities> capabilities() async =>
      const EncoderCapabilities({Codec.png: 8192});
  @override
  Future<EncodeSession> start(EncodeSpec spec) async => _PngSession(
    await createExportOutput(spec.outputPath),
    p.basenameWithoutExtension(spec.outputPath),
  );
}

class _PngSession implements EncodeSession {
  final ExportOutputSink sink;
  final String stem;
  final _stream = _DrainingZipStream();
  final _zip = ZipEncoder();
  bool _closed = false;
  _PngSession(this.sink, this.stem) {
    _zip.startEncode(_stream, level: 0);
  }
  @override
  Future<void> append(ui.Image frame, int index) async {
    final png = await frame.toByteData(format: ui.ImageByteFormat.png);
    if (png == null) {
      throw const EncoderException(
        EncoderFailureKind.failed,
        'A frame couldn’t be encoded.',
      );
    }
    final bytes = png.buffer.asUint8List(png.offsetInBytes, png.lengthInBytes);
    final entry = ArchiveFile.noCompress(
      '${stem}_${(index + 1).toString().padLeft(6, '0')}.png',
      bytes.length,
      bytes,
    );
    _zip.add(entry, autoClose: true);
    await sink.write(_stream.drain());
  }

  @override
  Future<EncodedFile> finish() async {
    if (_closed) throw StateError('Sequence already closed');
    _closed = true;
    _zip.endEncode();
    await sink.write(_stream.drain());
    return sink.finish();
  }

  @override
  Future<void> cancel() async {
    _closed = true;
    _stream.clear();
    await sink.cancel();
  }
}

/// Drains each entry while retaining cumulative offsets for the ZIP directory.
class _DrainingZipStream extends OutputStream {
  final _pending = BytesBuilder(copy: false);
  int _length = 0;
  _DrainingZipStream() : super(byteOrder: ByteOrder.littleEndian);
  Uint8List drain() => _pending.takeBytes();
  @override
  int get length => _length;
  @override
  void writeByte(int value) {
    _pending.addByte(value);
    _length++;
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    final data = length == null ? bytes : bytes.sublist(0, length);
    _pending.add(data);
    _length += data.length;
  }

  @override
  void writeStream(InputStream stream) =>
      writeBytes(stream.readBytes(stream.length).toUint8List());
  @override
  void clear() => _pending.clear();
  @override
  void flush() {}
  @override
  Uint8List subset(int start, [int? end]) =>
      throw UnsupportedError('ZIP output is append-only');
}
