import 'dart:io';
import 'package:flutter/services.dart';
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
  Future<Result<void>> download(ExportArtifact artifact) async {
    if (!Platform.isMacOS) return share(artifact);
    try {
      await const MethodChannel(
        'lastreel/export_destination',
      ).invokeMethod<bool>('saveExport', {'path': artifact.location});
      return const Ok(null);
    } catch (error, stack) {
      return Err(
        AppFailure(
          FailureKind.unknown,
          'Couldn’t save the export. Choose another destination and try again.',
          cause: error,
          stackTrace: stack,
        ),
      );
    }
  }

  String get _library => Platform.isAndroid ? 'Gallery' : 'Photos';

  String get _permissionHelp => Platform.isAndroid
      ? 'Allow storage access in Settings → Apps → LastReel → Permissions, then retry.'
      : 'Allow LastReel to add photos in Settings → Apps → LastReel → Photos, then retry.';

  @override
  Future<Result<void>> saveToPhotos(ExportArtifact artifact) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        return Err(AppFailure(FailureKind.permission, _permissionHelp));
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
            GalExceptionType.accessDenied => _permissionHelp,
            GalExceptionType.notEnoughSpace =>
              'Not enough free space to save to $_library. Free up space and retry.',
            GalExceptionType.notSupportedFormat =>
              '$_library can’t hold this format — share it instead.',
            GalExceptionType.unexpected =>
              'Couldn’t save to $_library. Try again or share the video.',
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
          files: [XFile(artifact.location, mimeType: artifact.mimeType)],
          fileNameOverrides: [artifact.filename],
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
