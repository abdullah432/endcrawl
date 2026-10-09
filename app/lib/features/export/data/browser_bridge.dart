import 'dart:js_interop';
import '../models/export_models.dart';
import 'video_encoder.dart';

@JS('endcrawlExport.capabilities')
external JSPromise<JSString> browserCapabilities();
@JS('endcrawlExport.create')
external JSPromise<JSAny?> browserCreate(JSString id);
@JS('endcrawlExport.write')
external JSPromise<JSAny?> browserWrite(JSString id, JSUint8Array bytes);
@JS('endcrawlExport.finish')
external JSPromise<JSNumber> browserFinish(JSString id);
@JS('endcrawlExport.release')
external JSPromise<JSAny?> browserRelease(JSString id);
@JS('endcrawlExport.videoStart')
external JSPromise<JSAny?> browserVideoStart(
  JSString id,
  JSNumber width,
  JSNumber height,
  JSNumber num,
  JSNumber den,
  JSNumber bitrate,
);
@JS('endcrawlExport.videoAppend')
external JSPromise<JSAny?> browserVideoAppend(
  JSString id,
  JSUint8Array rgba,
  JSNumber index,
);
@JS('endcrawlExport.videoFinish')
external JSPromise<JSNumber> browserVideoFinish(JSString id);
@JS('endcrawlExport.download')
external JSPromise<JSAny?> browserDownload(JSString id, JSString filename);
@JS('endcrawlExport.canShare')
external JSBoolean browserCanShare(JSString id, JSString filename);
@JS('endcrawlExport.share')
external JSPromise<JSAny?> browserShare(JSString id, JSString filename);

EncoderException browserEncoderFailure(Object error) {
  final detail = error.toString();
  if (detail.contains('QUOTA') || detail.contains('QuotaExceeded')) {
    return const EncoderException(
      EncoderFailureKind.outOfSpace,
      'Browser storage is full. Try a lower resolution or free some space.',
    );
  }
  if (detail.contains('UNSUPPORTED') || detail.contains('NotSupported')) {
    return const EncoderException(
      EncoderFailureKind.unsupported,
      'This browser cannot encode that size and frame rate. Try a smaller size or another browser.',
    );
  }
  return const EncoderException(
    EncoderFailureKind.failed,
    'The browser could not finish this export. Try again at a lower resolution.',
  );
}
