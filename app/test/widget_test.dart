import 'package:endcrawl/bootstrap.dart';
import 'package:endcrawl/core/result.dart';
import 'package:endcrawl/data/repositories/auth_repository.dart';
import 'package:endcrawl/data/sources/session_store.dart';
import 'package:endcrawl/domain/models/credit_block.dart';
import 'package:endcrawl/domain/models/project.dart';
import 'package:endcrawl/domain/models/project_settings.dart';
import 'package:endcrawl/features/onboarding/widgets/roll_hero.dart';
import 'package:endcrawl/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_auth_repository.dart';
import 'support/fake_project_repository.dart';

void main() {
  late FakeProjectRepository repository;
  late FakeAuthRepository auth;
  late InMemorySessionStore session;

  setUp(() {
    repository = FakeProjectRepository();
    auth = FakeAuthRepository(initialUser: testUser);
    session = InMemorySessionStore();
  });

  tearDown(() => auth.dispose());

  // A portrait phone-sized surface — the default test surface (800x600) is
  // landscape, which would exercise the rotate-to-preview full-bleed
  // monitor instead of the normal editor UI these tests check.
  void setPortraitSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  /// Turns the welcome screen's credit roll off for the duration of a test.
  ///
  /// It loops forever by design, and `pumpAndSettle` waits for a frame that
  /// never comes. Reduce-motion is the honest way to stop it: the widget
  /// already honours it, so this asserts real behaviour rather than
  /// installing a test-only escape hatch.
  void setReducedMotion(WidgetTester tester) {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    setPortraitSurface(tester);
    setReducedMotion(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authRepositoryProvider.overrideWithValue(auth),
          projectRepositoryProvider.overrideWithValue(repository),
          sessionStoreProvider.overrideWithValue(session),
        ],
        child: const EndcrawlApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Library → templates → format → editor, the full new-project path.
  Future<void> openShortFilmEditor(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('New project'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Short Film'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
  }

  /// Welcome → "Continue with email", the start of every credential path.
  Future<void> openEmailSignIn(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Continue with email'));
    await tester.pumpAndSettle();
  }

  Future<void> fillCredentials(
    WidgetTester tester, {
    String email = 'mara@example.com',
    String password = 'correct-horse',
  }) async {
    await tester.enterText(find.byType(TextField).first, email);
    await tester.enterText(find.byType(TextField).last, password);
  }

  group('Auth gate', () {
    testWidgets('shows the welcome screen when signed out', (tester) async {
      auth = FakeAuthRepository();
      await pumpApp(tester);

      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Continue with email'), findsOneWidget);
      expect(find.text('No projects yet'), findsNothing);
    });

    testWidgets('signing in swaps the tree to the library without navigating', (tester) async {
      auth = FakeAuthRepository();
      await openEmailSignIn(tester);

      await fillCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(auth.signInWithEmailCalls, 1);
      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('signing in from a pushed screen leaves no auth route on top', (tester) async {
      // The auth screens push onto the gate's own nested Navigator. On the
      // root one the library would appear *underneath* the screen the user
      // signed in from, which never got popped.
      auth = FakeAuthRepository();
      await openEmailSignIn(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await fillCredentials(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(auth.registerCalls, 1);
      expect(find.text('No projects yet'), findsOneWidget);
      expect(find.text('Create account'), findsNothing);
    });

    testWidgets('signing out returns to the welcome screen', (tester) async {
      await pumpApp(tester);
      expect(find.text('No projects yet'), findsOneWidget);

      await auth.signOut();
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('shows the provider failure message', (tester) async {
      auth = FakeAuthRepository()
        ..failWith = const AppFailure(FailureKind.permission, 'That email or password is not right.');
      await openEmailSignIn(tester);

      await fillCredentials(tester, password: 'wrong');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('That email or password is not right.'), findsOneWidget);
    });

    testWidgets('validates locally before hitting the provider', (tester) async {
      auth = FakeAuthRepository();
      await openEmailSignIn(tester);

      await fillCredentials(tester, email: 'not-an-email');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(auth.signInWithEmailCalls, 0);
    });

    testWidgets('a failure does not follow the user to the next screen', (tester) async {
      // All four screens share one controller, so navigation has to clear it.
      auth = FakeAuthRepository();
      await openEmailSignIn(tester);

      await fillCredentials(tester, email: 'not-an-email');
      await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsNothing);
    });
  });

  group('Welcome screen', () {
    testWidgets('signs in with Google straight from the first screen', (tester) async {
      auth = FakeAuthRepository();
      await pumpApp(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(auth.signInWithGoogleCalls, 1);
      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('a cancelled Google sign-in is not shown as an error', (tester) async {
      auth = FakeAuthRepository()..failWith = cancelledByUser;
      await pumpApp(tester);

      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      expect(auth.signInWithGoogleCalls, 1);
      expect(find.text('Sign-in cancelled.'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('lays out in landscape without overflowing', (tester) async {
      // The panel bottoms out its buttons with spacers, which on a short
      // window would overflow rather than scroll. A layout error here fails
      // the test, so this guards the scroll view that prevents it.
      auth = FakeAuthRepository();
      setReducedMotion(tester);
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            projectRepositoryProvider.overrideWithValue(repository),
            sessionStoreProvider.overrideWithValue(session),
          ],
          child: const EndcrawlApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('holds the credit roll still when the device asks for reduced motion', (tester) async {
      auth = FakeAuthRepository();
      // pumpApp turns reduced motion on; settling at all is the assertion —
      // a running roll would spin pumpAndSettle until it timed out.
      await pumpApp(tester);

      expect(find.byType(RollHero), findsOneWidget);
    });

    testWidgets('rolls the credits when motion is allowed', (tester) async {
      auth = FakeAuthRepository();
      setPortraitSurface(tester);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(auth),
            projectRepositoryProvider.overrideWithValue(repository),
            sessionStoreProvider.overrideWithValue(session),
          ],
          child: const EndcrawlApp(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final before = tester.getTopLeft(find.text('THE LONG WAY DOWN').first);
      await tester.pump(const Duration(seconds: 4));
      final after = tester.getTopLeft(find.text('THE LONG WAY DOWN').first);

      expect(after.dy, lessThan(before.dy));
    });
  });

  group('Create account', () {
    testWidgets('is its own screen, reached from sign-in', (tester) async {
      auth = FakeAuthRepository();
      await openEmailSignIn(tester);

      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Create account'), findsOneWidget);
      expect(find.text('At least 6 characters'), findsWidgets);
    });

    testWidgets('rejects a short password without a round trip', (tester) async {
      auth = FakeAuthRepository();
      await openEmailSignIn(tester);
      await tester.tap(find.text('Create an account'));
      await tester.pumpAndSettle();

      await fillCredentials(tester, password: 'short');
      await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a password of at least 6 characters.'), findsOneWidget);
      expect(auth.registerCalls, 0);
    });
  });

  group('Forgot password', () {
    Future<void> openReset(WidgetTester tester) async {
      await openEmailSignIn(tester);
      await tester.enterText(find.byType(TextField).first, 'mara@example.com');
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();
    }

    testWidgets('carries the address over from the sign-in screen', (tester) async {
      auth = FakeAuthRepository();
      await openReset(tester);

      expect(find.widgetWithText(FilledButton, 'Send reset link'), findsOneWidget);
      expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, 'mara@example.com');
    });

    testWidgets('confirms without revealing whether the account exists', (tester) async {
      auth = FakeAuthRepository();
      await openReset(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(auth.passwordResetSentTo, 'mara@example.com');
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.textContaining('If an account exists'), findsOneWidget);
    });

    testWidgets('will not send to an address that is not one', (tester) async {
      auth = FakeAuthRepository();
      await openEmailSignIn(tester);
      await tester.tap(find.text('Forgot password?'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'nope');
      await tester.tap(find.widgetWithText(FilledButton, 'Send reset link'));
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(auth.passwordResetSentTo, isNull);
    });
  });

  group('Library', () {
    testWidgets('shows an empty state when nothing is stored', (tester) async {
      await pumpApp(tester);

      expect(find.text('ENDCRAWL'), findsOneWidget);
      expect(find.text('No projects yet'), findsOneWidget);
    });

    testWidgets('lists stored projects newest first', (tester) async {
      repository = FakeProjectRepository(seed: [
        Project.create(title: 'OLDER').copyWith(updatedAt: DateTime.utc(2026, 1, 1)),
        Project.create(title: 'NEWER').copyWith(updatedAt: DateTime.utc(2026, 5, 1)),
      ]);
      await pumpApp(tester);

      expect(find.text('YOUR PROJECTS'), findsOneWidget);
      final titles = tester.widgetList<Text>(find.byType(Text)).map((t) => t.data).toList();
      expect(titles.indexOf('NEWER') < titles.indexOf('OLDER'), isTrue);
    });

    testWidgets('offers a crash recovery for a project this device left open', (tester) async {
      final project = Project.create(title: 'THE LONG WAY DOWN');
      repository = FakeProjectRepository(seed: [project]);
      session = InMemorySessionStore(SessionState(lastOpenedProjectId: project.id, leftOpenProjectId: project.id));
      await pumpApp(tester);

      expect(find.text('RECOVERED AFTER CRASH'), findsOneWidget);
      expect(find.text('Open recovered'), findsOneWidget);
    });

    testWidgets('offers a plain resume for a project that was closed cleanly', (tester) async {
      final project = Project.create(title: 'THE LONG WAY DOWN');
      repository = FakeProjectRepository(seed: [project]);
      session = InMemorySessionStore(SessionState(lastOpenedProjectId: project.id));
      await pumpApp(tester);

      expect(find.text('CONTINUE WHERE YOU LEFT OFF'), findsOneWidget);
      expect(find.text('Continue'), findsOneWidget);
    });

    testWidgets('surfaces a storage failure with a retry', (tester) async {
      repository.failWith = const AppFailure(FailureKind.storage, 'Could not reach on-device storage.');
      await pumpApp(tester);

      expect(find.text('Could not reach on-device storage.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('opens a stored project into the editor', (tester) async {
      repository = FakeProjectRepository(seed: [
        Project.create(
          title: 'MY FILM',
          blocks: const [TitleBlock(id: 'b1', title: 'MY FILM')],
        ),
      ]);
      await pumpApp(tester);

      await tester.tap(find.text('MY FILM'));
      await tester.pumpAndSettle();

      expect(find.textContaining('blocks · drag to reorder'), findsOneWidget);
    });
  });

  group('New project flow', () {
    testWidgets('templates screen offers the starting points', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();

      expect(find.text('Pick a starting point.\nChange anything later.'), findsOneWidget);
      expect(find.text('Short Film'), findsOneWidget);
    });

    testWidgets('picking a template opens the format screen', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Short Film'));
      await tester.pumpAndSettle();

      expect(find.text('Canvas format'), findsOneWidget);
    });

    testWidgets('opening the editor persists the project and renders the block list', (tester) async {
      await openShortFilmEditor(tester);

      expect(find.textContaining('blocks · drag to reorder'), findsOneWidget);
      expect(find.text('Export'), findsOneWidget);

      // Entering the editor writes the document — that is what makes it
      // appear in the library — and marks it open on this device, which is
      // what makes it recoverable.
      expect(repository.projects, hasLength(1));
      final stored = await session.read();
      expect(stored.leftOpenProjectId, repository.projects.keys.single);
      expect(stored.lastOpenedProjectId, repository.projects.keys.single);
    });

    testWidgets('leaving the editor clears the left-open mark', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.byIcon(Icons.chevron_left));
      await tester.pumpAndSettle();

      final stored = await session.read();
      expect(stored.leftOpenProjectId, isNull);
      expect(stored.lastOpenedProjectId, isNotNull);
    });

    testWidgets('an edit is autosaved without any explicit save action', (tester) async {
      await openShortFilmEditor(tester);
      final savesBeforeEdit = repository.saveCount;
      expect(repository.projects.values.single.settings.look, RollLook.flat2d);

      await tester.tap(find.text('2D'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('3D perspective crawl'));
      await tester.pumpAndSettle();

      // Nothing is written yet — the autosave is debounced so a burst of
      // edits coalesces into one write.
      expect(repository.saveCount, savesBeforeEdit);

      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();

      expect(repository.saveCount, greaterThan(savesBeforeEdit));
      expect(repository.projects.values.single.settings.look, RollLook.crawl3d);
    });

    testWidgets('start empty reaches an editor with no blocks', (tester) async {
      await pumpApp(tester);
      await tester.tap(find.text('New project'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('Start empty'), 300);
      await tester.tap(find.text('Start empty'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();

      expect(find.text('No blocks yet'), findsOneWidget);
    });
  });

  group('Editor', () {
    testWidgets('timing sheet opens and shows the judder/readability cards', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Timing'));
      await tester.pumpAndSettle();

      expect(find.text('Lock runtime'), findsOneWidget);
      expect(find.text('Head black'), findsOneWidget);
    });

    testWidgets('paste & split sheet parses the seed cast list', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Paste'));
      await tester.pumpAndSettle();

      expect(find.text('Paste & split'), findsOneWidget);
      expect(find.textContaining('Add '), findsWidgets);
    });

    testWidgets('export sheet opens on the idle/locked-settings state', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Export'));
      await tester.pumpAndSettle();

      expect(find.text('LOCKED FOR THIS RENDER'), findsOneWidget);
      expect(find.text('ProRes 4444'), findsWidgets);
    });

    testWidgets('tapping the cast block card opens the cast editor', (tester) async {
      await openShortFilmEditor(tester);

      await tester.scrollUntilVisible(find.text('Cast'), 300);
      await tester.tap(find.text('Cast'));
      await tester.pumpAndSettle();

      expect(find.text('Centre gutter'), findsOneWidget);
      expect(find.text('FAST ENTRY — NEXT HOPS ROLE → NAME → NEW ROW'), findsOneWidget);
    });

    testWidgets('select mode shows the bulk action bar', (tester) async {
      await openShortFilmEditor(tester);

      await tester.tap(find.text('Select'));
      await tester.pumpAndSettle();

      expect(find.text('Done'), findsOneWidget);
      expect(find.text('0 selected'), findsOneWidget);
      expect(find.text('Restyle'), findsOneWidget);
    });

    testWidgets('rotating to landscape shows the full-bleed monitor', (tester) async {
      await openShortFilmEditor(tester);

      tester.view.physicalSize = const Size(844, 390);
      await tester.pumpAndSettle();

      expect(find.textContaining('FULL-BLEED MONITOR'), findsOneWidget);
    });
  });
}
