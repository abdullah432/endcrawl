// Local QA entry point. Uses fixture repositories; never Firebase or store credentials.
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lastreel/main.dart';
import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/data/sources/session_store.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/domain/models/credit_block.dart';
import 'package:lastreel/features/cookoo/controllers/cookoo_contact_controller.dart';
import 'package:lastreel/features/cookoo/controllers/cookoo_promo_controller.dart';
import 'package:lastreel/features/cookoo/data/cookoo_store.dart';
import 'package:lastreel/features/review/review_prompt.dart';
import 'package:lastreel/features/review/review_prompt_store.dart';
import 'package:lastreel/features/desk/desk_invite.dart';
import 'package:lastreel/features/desk/desk_invite_store.dart';
import 'package:lastreel/features/tracking/tracking_prompt.dart';
import 'package:lastreel/features/tracking/tracking_store.dart';
import 'package:lastreel/features/tester/tester_mode.dart';
import 'support/fake_auth_repository.dart';
import 'support/fake_project_repository.dart';
import 'support/fake_user_profile_repository.dart';
import 'support/fake_entitlement_repository.dart';
import 'support/fake_analytics.dart';
import 'support/fake_cookoo_contact_client.dart';
import 'support/fixtures.dart';

void main() {
  const nativeAdQa = bool.fromEnvironment('AD_TABLET_QA');
  if (nativeAdQa && !kDebugMode) {
    throw StateError('Tablet ad QA requires debug mode and Google sample ads.');
  }
  WidgetsFlutterBinding.ensureInitialized();
  final seed = Uri.base.queryParameters.containsKey('short')
      ? film().copyWith(
          settings: film().settings.copyWith(
            ppf: 48,
            headSeconds: 0,
            tailSeconds: 0,
          ),
          blocks: const [
            HoldBlock(
              id: 'hold',
              lines: ['BROWSER EXPORT'],
              fadeIn: .2,
              hold: .6,
              fadeOut: .2,
            ),
          ],
        )
      : film();
  runApp(
    ProviderScope(
      overrides: [
        authRepositoryProvider.overrideWithValue(
          FakeAuthRepository(initialUser: testUser),
        ),
        projectRepositoryProvider.overrideWithValue(
          FakeProjectRepository(seed: [seed]),
        ),
        sessionStoreProvider.overrideWithValue(InMemorySessionStore()),
        userProfileRepositoryForProvider.overrideWith(
          (ref, uid) => FakeUserProfileRepository(),
        ),
        entitlementRepositoryProvider.overrideWithValue(
          FakeEntitlementRepository(
            nativeAdQa || Uri.base.queryParameters['plan'] == 'free'
                ? const Entitlement.free()
                : const Entitlement.pro(),
          ),
        ),
        analyticsProvider.overrideWithValue(FakeAnalytics()),
        cookooStoreProvider.overrideWithValue(InMemoryCookooStore()),
        reviewPromptStoreProvider.overrideWithValue(
          InMemoryReviewPromptStore(asked: true),
        ),
        cookooContactClientProvider.overrideWithValue(
          FakeCookooContactClient(),
        ),
        deskInviteStoreProvider.overrideWithValue(InMemoryDeskInviteStore(turnedOff: true)),
        trackingStoreProvider.overrideWithValue(InMemoryTrackingStore()),
        testerStoreProvider.overrideWithValue(InMemoryTesterStore()),
        testerAllowedProvider.overrideWith((ref) => Stream.value(false)),
      ],
      child: const LastReelApp(),
    ),
  );
}
