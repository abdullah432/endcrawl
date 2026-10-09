import 'dart:js_interop';
import 'dart:typed_data';
import 'browser_bridge.dart';
import 'output_sink.dart';
import 'video_encoder.dart';

Future<String> exportOutputDirectory() async =>
    'browser-export:${DateTime.now().microsecondsSinceEpoch}';
Future<void> releaseExportOutput(String location) async {
  await browserRelease(location.toJS).toDart;
}

Future<ExportOutputSink> createExportOutput(String location) async {
  try {
    await browserCreate(location.toJS).toDart;
    return _BrowserOutput(location);
  } catch (error) {
    throw browserEncoderFailure(error);
  }
}

class _BrowserOutput implements ExportOutputSink {
  final String location;
  _BrowserOutput(this.location);
  @override
  Future<void> write(Uint8List bytes) async {
    try {
      await browserWrite(location.toJS, bytes.toJS).toDart;
    } catch (error) {
      throw browserEncoderFailure(error);
    }
  }

  @override
  Future<EncodedFile> finish() async {
    try {
      return EncodedFile(
        location,
        (await browserFinish(location.toJS).toDart).toDartInt,
      );
    } catch (error) {
      throw browserEncoderFailure(error);
    }
  }

  @override
  Future<void> cancel() => releaseExportOutput(location);
}
