import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../bootstrap.dart';
import '../../../core/result.dart';
import '../../../domain/models/user_profile.dart';

/// "EndCrawl 1.0 (214)" at the foot of Settings.
final appVersionProvider = FutureProvider<String>((ref) async {
  final info = await PackageInfo.fromPlatform();
  return 'EndCrawl ${info.version} (${info.buildNumber})';
});

/// Settings actions. Preferences are written straight to the profile
/// document; Firestore's local cache reflects the write immediately, so the
/// switch moves at once and syncs when it can.
class SettingsController {
  final Ref _ref;
  const SettingsController(this._ref);

  UserProfile get _profile => _ref.read(userProfileProvider).value ?? const UserProfile();

  Future<Result<void>> updatePreferences(Preferences Function(Preferences) change) {
    final profile = _profile;
    return _ref.read(userProfileRepositoryProvider).save(profile.copyWith(preferences: change(profile.preferences)));
  }

  Future<Result<void>> signOut() => _ref.read(authRepositoryProvider).signOut();

  /// The system review prompt where the platform allows it, otherwise the
  /// store listing.
  Future<void> rate() async {
    final review = InAppReview.instance;
    try {
      if (await review.isAvailable()) {
        await review.requestReview();
      } else {
        await review.openStoreListing();
      }
    } on Object {
      // Nothing useful to tell the person if the store can't be reached.
    }
  }
}

final settingsControllerProvider = Provider<SettingsController>(SettingsController.new);
