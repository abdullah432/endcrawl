import 'dart:js_interop';
import 'dart:ui';
import '../../../core/result.dart';
import '../models/export_artifact.dart';
import 'browser_bridge.dart';
import 'export_destinations.dart';

class PlatformExportDestinations implements ExportDestinations {
  const PlatformExportDestinations();
  @override
  bool canShare(ExportArtifact artifact) =>
      browserCanShare(artifact.location.toJS, artifact.filename.toJS).toDart;
  @override
  Future<Result<void>> download(ExportArtifact artifact) async {
    try {
      await browserDownload(
        artifact.location.toJS,
        artifact.filename.toJS,
      ).toDart;
      return const Ok(null);
    } catch (_) {
      return const Err(
        AppFailure(
          FailureKind.unknown,
          'The download is no longer available. Render again.',
        ),
      );
    }
  }

  @override
  Future<Result<void>> saveToPhotos(ExportArtifact artifact) async => const Err(
    AppFailure(
      FailureKind.unknown,
      'Download the file to save it on this device.',
    ),
  );
  @override
  Future<Result<void>> share(ExportArtifact artifact, {Rect? origin}) async {
    try {
      await browserShare(artifact.location.toJS, artifact.filename.toJS).toDart;
      return const Ok(null);
    } catch (_) {
      return const Err(
        AppFailure(
          FailureKind.unknown,
          'Could not share this file. Download it instead.',
        ),
      );
    }
  }
}
