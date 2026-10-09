import 'dart:ui';

import '../../../core/result.dart';
import '../models/export_artifact.dart';
export 'export_destinations_native.dart'
    if (dart.library.js_interop) 'export_destinations_web.dart';

/// Where a finished render goes (6.4). An interface so the ready screen
/// can be tested without the Photos library or the share sheet.
abstract interface class ExportDestinations {
  Future<Result<void>> download(ExportArtifact artifact);
  bool canShare(ExportArtifact artifact);

  /// Adds a video to the photo library, asking for access the first time.
  Future<Result<void>> saveToPhotos(ExportArtifact artifact);

  /// Hands the file to the share sheet — which is also where "Save to
  /// Files" lives on both platforms. [origin] anchors the popover on iPad.
  Future<Result<void>> share(ExportArtifact artifact, {Rect? origin});
}
