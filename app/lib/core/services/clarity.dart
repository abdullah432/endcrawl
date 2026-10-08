/// Microsoft Clarity session recording, on the platforms it supports.
///
/// `clarity_flutter` is mobile-only and doesn't compile to JavaScript, so
/// everything imports Clarity from here: phones get the real package, the
/// web gets pass-through stand-ins and never compiles it.
library;

export 'clarity/clarity_web.dart' if (dart.library.io) 'clarity/clarity_mobile.dart';
