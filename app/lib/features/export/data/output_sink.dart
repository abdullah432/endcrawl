import 'dart:typed_data';
import 'video_encoder.dart';
export 'output_sink_native.dart'
    if (dart.library.js_interop) 'output_sink_web.dart';

abstract interface class ExportOutputSink {
  Future<void> write(Uint8List bytes);
  Future<EncodedFile> finish();
  Future<void> cancel();
}
