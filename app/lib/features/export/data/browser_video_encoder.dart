import 'video_encoder.dart';
import '../models/export_models.dart';

/// The web build's encoder: it lists every codec up to 4K, so the export
/// dialog (D14) shows exactly what Pro on the web includes, but it doesn't
/// encode yet — the native encoders the apps use don't exist in a browser.
/// Rendering in the browser (WebCodecs) is a separate step; until then the
/// dialog says to render on the phone or tablet.
class BrowserVideoEncoder implements VideoEncoder {
  const BrowserVideoEncoder();

  static const message = 'Rendering in the browser is coming. Render this on your phone or tablet for now.';

  @override
  Future<EncoderCapabilities> capabilities() async => EncoderCapabilities({for (final c in Codec.values) c: 3840});

  @override
  Future<EncodeSession> start(EncodeSpec spec) async =>
      throw const EncoderException(EncoderFailureKind.unsupported, message);
}
