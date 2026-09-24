import 'dart:ui';

import 'package:gal/gal.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/result.dart';

/// Where a finished render goes (6.4). An interface so the ready screen
/// can be tested without the Photos library or the share sheet.
abstract interface class ExportDestinations {
  /// Adds a video to the photo library, asking for access the first time.
  Future<Result<void>> saveToPhotos(String path);

  /// Hands the file to the share sheet — which is also where "Save to
  /// Files" lives on both platforms. [origin] anchors the popover on iPad.
  Future<Result<void>> share(String path, {Rect? origin});
}

class PlatformExportDestinations implements ExportDestinations {
  const PlatformExportDestinations();

  @override
  Future<Result<void>> saveToPhotos(String path) async {
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
        return const Err(AppFailure(FailureKind.permission, 'Allow EndCrawl to add to Photos in Settings.'));
      }
      await Gal.putVideo(path);
      return const Ok(null);
    } on GalException catch (e, s) {
      return Err(AppFailure(
        e.type == GalExceptionType.accessDenied ? FailureKind.permission : FailureKind.unknown,
        switch (e.type) {
          GalExceptionType.accessDenied => 'Allow EndCrawl to add to Photos in Settings.',
          GalExceptionType.notEnoughSpace => 'Not enough free space in Photos.',
          GalExceptionType.notSupportedFormat => 'Photos can’t hold this format — share it instead.',
          GalExceptionType.unexpected => 'Couldn’t save to Photos.',
        },
        cause: e,
        stackTrace: s,
      ));
    }
  }

  @override
  Future<Result<void>> share(String path, {Rect? origin}) async {
    try {
      await SharePlus.instance.share(ShareParams(files: [XFile(path)], sharePositionOrigin: origin));
      return const Ok(null);
    } catch (e, s) {
      return Err(AppFailure(FailureKind.unknown, 'Couldn’t open the share sheet.', cause: e, stackTrace: s));
    }
  }
}
