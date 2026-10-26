import 'package:lastreel/bootstrap.dart';
import 'package:lastreel/core/services/profile_sync.dart';
import 'package:lastreel/core/config/release_config.dart';
import 'package:lastreel/data/sources/session_store.dart';
import 'package:lastreel/features/ads/ads_providers.dart';
import 'package:lastreel/features/cookoo/controllers/cookoo_contact_controller.dart';
import 'package:lastreel/features/cookoo/controllers/cookoo_promo_controller.dart';
import 'package:lastreel/features/cookoo/data/cookoo_store.dart';
import 'package:lastreel/features/export/controllers/export_controller.dart';
import 'package:lastreel/features/access/controllers/web_access.dart';
import 'package:lastreel/features/desk/desk_invite.dart';
import 'package:lastreel/features/desk/desk_invite_store.dart';
import 'package:lastreel/features/review/data/feedback_repository.dart';
import 'package:lastreel/features/tester/tester_mode.dart';
import 'package:lastreel/features/review/review_prompt.dart';
import 'package:lastreel/features/review/review_prompt_store.dart';
import 'package:lastreel/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_analytics.dart';
import 'fake_auth_repository.dart';
import 'fake_cookoo_contact_client.dart';
import 'fake_entitlement_repository.dart';
import 'fake_export.dart';
import 'fake_external_links.dart';
import 'fake_feedback_repository.dart';
import 'fake_project_repository.dart';
import 'fake_user_profile_repository.dart';

/// The whole app, wired to in-memory fakes through the same providers
/// `bootstrap()` fills in production.
///
/// One harness for every feature's widget tests, so a new provider needs
/// overriding in exactly one place.
class AppHarness {
  FakeAuthRepository auth;
  FakeProjectRepository projects;
  InMemorySessionStore session;
  FakeUserProfileRepository profile;
  FakeExternalLinks links;
  FakeEntitlementRepository plan;
  FakeVideoEncoder encoder;
  FakeFrames frames;
  FakeExportDestinations destinations;
  FakeAdService ads;
  FakeAnalytics analytics;
  InMemoryCookooStore cookoo;
  InMemoryReviewPromptStore review;
  FakeCookooContactClient contact;
  FakeFeedbackRepository feedback;
  InMemoryDeskInviteStore desk;

  /// The desk invite's roll ("by chance"): a sure thing unless a test says.
  bool deskChance;
  InMemoryTesterStore testerMode;

  /// Whether this account is listed as a tester (Firestore `testers/{uid}`).
  bool testerAllowed;
  DateTime now;

  /// Runs the app as the web build would (the Pro workspace rules).
  bool web;

  /// Null exercises the build's default; false tests restored subscriptions.
  bool? iosFreeLaunch;
  ProfileSync? profileSync;

  AppHarness({
    FakeAuthRepository? auth,
    FakeProjectRepository? projects,
    InMemorySessionStore? session,
    FakeUserProfileRepository? profile,
    FakeExternalLinks? links,
    FakeEntitlementRepository? plan,
    FakeVideoEncoder? encoder,
    FakeFrames? frames,
    InMemoryCookooStore? cookoo,
    InMemoryReviewPromptStore? review,
    InMemoryDeskInviteStore? desk,
    DateTime? now,
    this.web = false,
    this.iosFreeLaunch,
    this.profileSync,
    this.testerAllowed = false,
    this.deskChance = true,
  }) : auth = auth ?? FakeAuthRepository(initialUser: testUser),
       projects = projects ?? FakeProjectRepository(),
       session = session ?? InMemorySessionStore(),
       profile = profile ?? FakeUserProfileRepository(),
       links = links ?? FakeExternalLinks(),
       plan = plan ?? FakeEntitlementRepository(),
       encoder = encoder ?? FakeVideoEncoder(),
       frames = frames ?? FakeFrames(),
       destinations = FakeExportDestinations(),
       ads = FakeAdService(),
       analytics = FakeAnalytics(),
       cookoo = cookoo ?? InMemoryCookooStore(),
       // Already asked by default, so the one-time rating prompt doesn't
       // cover the screen in tests about something else.
       review = review ?? InMemoryReviewPromptStore(asked: true),
       contact = FakeCookooContactClient(),
       feedback = FakeFeedbackRepository(),
       // Off by default, so the desk invite doesn't cover the library in
       // tests about something else.
       desk = desk ?? InMemoryDeskInviteStore(turnedOff: true),
       testerMode = InMemoryTesterStore(),
       now = now ?? DateTime.utc(2026, 9, 23, 12);

  /// A signed-out start.
  factory AppHarness.signedOut() => AppHarness(auth: FakeAuthRepository());

  static const phone = Size(390, 844);

  /// Pumps the app at [size] (a portrait phone by default) and settles.
  ///
  /// Reduce-motion is on unless [motion] is set: the welcome roll loops
  /// forever by design, and the widget honours reduce-motion, so this is
  /// real behaviour rather than a test-only escape hatch.
  Future<void> pump(
    WidgetTester tester, {
    Size size = phone,
    bool motion = false,
    bool settle = true,
  }) async {
    tester.view.display.size = size;
    tester.view.display.devicePixelRatio = 1;
    addTearDown(tester.view.display.reset);
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!motion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
    }
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          if (profileSync case final sync?)
            profileSyncProvider.overrideWithValue(sync),
          if (iosFreeLaunch case final enabled?)
            iosFreeLaunchFlagProvider.overrideWithValue(enabled),
          authRepositoryProvider.overrideWithValue(auth),
          projectRepositoryProvider.overrideWithValue(projects),
          sessionStoreProvider.overrideWithValue(session),
          userProfileRepositoryForProvider.overrideWith((ref, uid) => profile),
          externalLinksProvider.overrideWithValue(links),
          entitlementRepositoryProvider.overrideWithValue(plan),
          clockProvider.overrideWithValue(() => now),
          videoEncoderProvider.overrideWithValue(encoder),
          frameSourceFactoryProvider.overrideWithValue(frames.open),
          exportDestinationsProvider.overrideWithValue(destinations),
          exportDirectoryProvider.overrideWithValue(() async => '/renders'),
          adServiceProvider.overrideWithValue(ads),
          analyticsProvider.overrideWithValue(analytics),
          cookooStoreProvider.overrideWithValue(cookoo),
          reviewPromptStoreProvider.overrideWithValue(review),
          runningOnWebProvider.overrideWithValue(web),
          cookooContactClientProvider.overrideWithValue(contact),
          feedbackRepositoryProvider.overrideWithValue(feedback),
          deskInviteStoreProvider.overrideWithValue(desk),
          deskInviteChanceProvider.overrideWithValue(() => deskChance),
          testerStoreProvider.overrideWithValue(testerMode),
          testerAllowedProvider.overrideWith(
            (ref) => Stream.value(testerAllowed),
          ),
        ],
        child: const LastReelApp(),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}
