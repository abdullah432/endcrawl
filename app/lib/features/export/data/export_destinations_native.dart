import 'dart:ui';
import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/result.dart';
import '../models/export_artifact.dart';
import 'export_destinations.dart';

class PlatformExportDestinations implements ExportDestinations {
  const PlatformExportDestinations();

  @override
  bool canShare(ExportArtifact artifact) => true;
  @override
  Future<Result<void>> download(ExportArtifact artifact) => share(artifact);

  @override
  Future<Result<void>> saveToPhotos(ExportArtifact artifact) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        return const Err(
          AppFailure(
            FailureKind.permission,
            'Allow LastReel to add to Photos in Settings.',
          ),
        );
      }
      await Gal.putVideo(artifact.location);
      return const Ok(null);
    } on GalException catch (e, s) {
      return Err(
        AppFailure(
          e.type == GalExceptionType.accessDenied
              ? FailureKind.permission
              : FailureKind.unknown,
          switch (e.type) {
            GalExceptionType.accessDenied =>
              'Allow LastReel to add to Photos in Settings.',
            GalExceptionType.notEnoughSpace =>
              'Not enough free space in Photos.',
            GalExceptionType.notSupportedFormat =>
              'Photos can’t hold this format — share it instead.',
            GalExceptionType.unexpected => 'Couldn’t save to Photos.',
          },
          cause: e,
          stackTrace: s,
        ),
      );
    }
  }

  @override
  Future<Result<void>> share(ExportArtifact artifact, {Rect? origin}) async {
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(artifact.location)],
          sharePositionOrigin: origin,
        ),
      );
      return const Ok(null);
    } catch (e, s) {
      return Err(
        AppFailure(
          FailureKind.unknown,
          'Couldn’t open the share sheet.',
          cause: e,
          stackTrace: s,
        ),
      );
    }
  }
}
