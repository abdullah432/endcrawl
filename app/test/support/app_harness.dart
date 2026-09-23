import 'package:endcrawl/bootstrap.dart';
import 'package:endcrawl/data/sources/session_store.dart';
import 'package:endcrawl/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_auth_repository.dart';
import 'fake_external_links.dart';
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
  DateTime now;

  AppHarness({
    FakeAuthRepository? auth,
    FakeProjectRepository? projects,
    InMemorySessionStore? session,
    FakeUserProfileRepository? profile,
    FakeExternalLinks? links,
    DateTime? now,
  })  : auth = auth ?? FakeAuthRepository(initialUser: testUser),
        projects = projects ?? FakeProjectRepository(),
        session = session ?? InMemorySessionStore(),
        profile = profile ?? FakeUserProfileRepository(),
        links = links ?? FakeExternalLinks(),
        now = now ?? DateTime.utc(2026, 9, 23, 12);

  /// A signed-out start.
  factory AppHarness.signedOut() => AppHarness(auth: FakeAuthRepository());

  static const phone = Size(390, 844);

  /// Pumps the app at [size] (a portrait phone by default) and settles.
  ///
  /// Reduce-motion is on unless [motion] is set: the welcome roll loops
  /// forever by design, and the widget honours reduce-motion, so this is
  /// real behaviour rather than a test-only escape hatch.
  Future<void> pump(WidgetTester tester, {Size size = phone, bool motion = false, bool settle = true}) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    if (!motion) {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    }
    addTearDown(auth.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          projectRepositoryProvider.overrideWithValue(projects),
          sessionStoreProvider.overrideWithValue(session),
          userProfileRepositoryForProvider.overrideWith((ref, uid) => profile),
          externalLinksProvider.overrideWithValue(links),
          clockProvider.overrideWithValue(() => now),
        ],
        child: const EndcrawlApp(),
      ),
    );
    if (settle) await tester.pumpAndSettle();
  }
}
