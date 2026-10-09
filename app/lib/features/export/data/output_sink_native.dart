import 'dart:io';
import 'dart:typed_data';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'output_sink.dart';
import 'video_encoder.dart';

Future<String> exportOutputDirectory() async {
  final directory = Directory(
    p.join((await getTemporaryDirectory()).path, 'renders'),
  );
  await directory.create(recursive: true);
  return directory.path;
}

Future<void> releaseExportOutput(String location) async {
  final file = File(location);
  if (await file.exists()) await file.delete();
}

Future<ExportOutputSink> createExportOutput(String location) async =>
    _FileOutput(location);

class _FileOutput implements ExportOutputSink {
  final String location;
  late final IOSink _sink = File(location).openWrite();
  bool _closed = false;
  _FileOutput(this.location);
  @override
  Future<void> write(Uint8List bytes) async {
    try {
      _sink.add(bytes);
      await _sink.flush();
    } on FileSystemException catch (error) {
      if ([28, 112].contains(error.osError?.errorCode)) {
        throw const EncoderException.outOfSpace();
      }
      rethrow;
    }
  }

  Future<void> _close() async {
    if (!_closed) {
      _closed = true;
      await _sink.close();
    }
  }

  @override
  Future<EncodedFile> finish() async {
    await _close();
    return EncodedFile(location, await File(location).length());
  }

  @override
  Future<void> cancel() async {
    try {
      await _close();
    } finally {
      await releaseExportOutput(location);
    }
  }
}
