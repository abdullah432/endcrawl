import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/auth_repository.dart';
import 'package:lastreel/domain/models/app_user.dart';
import 'package:lastreel/core/widgets/ec_fields.dart';
import 'package:lastreel/features/auth/widgets/legal_consent.dart';
import 'package:lastreel/features/library/screens/library_screen.dart';
import 'package:lastreel/features/onboarding/widgets/roll_hero.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';

final _library = find.byType(LibraryScreen);

void main() {
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String label, String value) async {
    final field = find.descendant(
      of: find.ancestor(of: find.text(label), matching: find.byType(Column)).first,
      matching: find.byType(TextField),
    );
    await tester.enterText(field.first, value);
  }

  group('0.1 Welcome', () {
    testWidgets('offers Google and email, with the credits rolling; Apple is off', (tester) async {
      await AppHarness.signedOut().pump(tester);

      expect(find.text('Continue with Apple'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(find.text('Sign up with email'), findsOneWidget);
      expect(find.byType(RollHero), findsOneWidget);
    });

    testWidgets('Google signs in straight from the first screen', (tester) async {
      final app = AppHarness.signedOut();
      await app.pump(tester);

      await tapText(tester, 'Continue with Google');

      expect(app.auth.signInWithGoogleCalls, 1);
      expect(_library, findsOneWidget);
    });

    testWidgets('a cancelled provider sheet is not an error', (tester) async {
      final app = AppHarness(auth: FakeAuthRepository()..failWith = cancelledByUser);
      await app.pump(tester);

      await tapText(tester, 'Continue with Google');

      expect(find.text('Sign-in cancelled.'), findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('a provider outage is shown above the buttons', (tester) async {
      final app = AppHarness(
        auth: FakeAuthRepository()..failWith = const AppFailure(FailureKind.network, 'Google Sign-In is unavailable right now.'),
      );
      await app.pump(tester);

      await tapText(tester, 'Continue with Google');

      expect(find.text('Google Sign-In is unavailable right now.'), findsOneWidget);
    });

    testWidgets('holds the credit roll still under reduced motion', (tester) async {
      // pump() turns reduced motion on; settling at all is the assertion.
      await AppHarness.signedOut().pump(tester);
      expect(find.byType(RollHero), findsOneWidget);
    });

    testWidgets('rolls the credits when motion is allowed', (tester) async {
      await AppHarness.signedOut().pump(tester, motion: true, settle: false);
      await tester.pump(const Duration(milliseconds: 100));

      final before = tester.getTopLeft(find.text('YUSUF KARADENIZ').first);
      await tester.pump(const Duration(seconds: 2));
      final after = tester.getTopLeft(find.text('YUSUF KARADENIZ').first);

      expect(after.dy, lessThan(before.dy));
    });

    testWidgets('lays out in landscape without overflowing', (tester) async {
      await AppHarness.signedOut().pump(tester, size: const Size(844, 390));
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('the terms open in the app', (tester) async {
      await AppHarness.signedOut().pump(tester);

      await tester.ensureVisible(find.byType(LegalConsent));
      await tester.pumpAndSettle();
      await tester.tapOnText(find.textRange.ofSubstring('Privacy Policy'));
      await tester.pumpAndSettle();

      expect(find.text('Privacy policy'), findsOneWidget);
      expect(find.textContaining('What we collect'), findsOneWidget);
    });
  });

  group('0.2 Sign in', () {
    Future<AppHarness> openSignIn(WidgetTester tester, {FakeAuthRepository? auth}) async {
      final app = AppHarness(auth: auth ?? FakeAuthRepository());
      await app.pump(tester);
      await tapText(tester, 'Sign in');
      return app;
    }

    testWidgets('signs in and swaps to the library without navigating', (tester) async {
      final app = await openSignIn(tester);

      await fill(tester, 'Email', 'maya@okonkwo.studio');
      await fill(tester, 'Password', 'correct-horse-1');
      await tester.tap(find.widgetWithText(InkWell, 'Sign in').last);
      await tester.pumpAndSettle();

      expect(app.auth.signInWithEmailCalls, 1);
      expect(_library, findsOneWidget);
    });

    testWidgets('a wrong password is reported under the password field', (tester) async {
      final app = await openSignIn(
        tester,
        auth: FakeAuthRepository()
          ..failWith = const AppFailure(
            FailureKind.permission,
            'That password doesn’t match this email. Try again or reset it.',
            field: AuthField.password,
          ),
      );

      await fill(tester, 'Email', 'maya@okonkwo.studio');
      await fill(tester, 'Password', 'wrong');
      await tester.tap(find.widgetWithText(InkWell, 'Sign in').last);
      await tester.pumpAndSettle();

      expect(app.auth.signInWithEmailCalls, 1);
      expect(find.text('That password doesn’t match this email. Try again or reset it.'), findsOneWidget);
    });

    testWidgets('an invalid email is caught before any request', (tester) async {
      final app = await openSignIn(tester);

      await fill(tester, 'Email', 'not-an-email');
      await fill(tester, 'Password', 'whatever1');
      await tester.tap(find.widgetWithText(InkWell, 'Sign in').last);
      await tester.pumpAndSettle();

      expect(find.text('Enter a valid email address.'), findsOneWidget);
      expect(app.auth.signInWithEmailCalls, 0);
    });

    testWidgets('keeps Google available', (tester) async {
      await openSignIn(tester);
      expect(find.text('Apple'), findsNothing);
      expect(find.text('Google'), findsOneWidget);
    });

    testWidgets('an error does not follow the user to the next screen', (tester) async {
      await openSignIn(tester);
      await fill(tester, 'Email', 'nope');
      await tester.tap(find.widgetWithText(InkWell, 'Sign in').last);
      await tester.pumpAndSettle();
      expect(find.text('Enter a valid email address.'), findsOneWidget);

      await tapText(tester, 'Create account');

      expect(find.text('Enter a valid email address.'), findsNothing);
    });
  });

  group('0.3 Create account', () {
    Future<AppHarness> openCreate(WidgetTester tester) async {
      final app = AppHarness.signedOut();
      await app.pump(tester);
      await tapText(tester, 'Sign up with email');
      return app;
    }

    testWidgets('ticks the password rules off as you type', (tester) async {
      await openCreate(tester);

      await fill(tester, 'Password', 'abcdefgh');
      await tester.pump();
      final lengthRule = tester.widget<Semantics>(
        find.ancestor(of: find.text('At least 8 characters'), matching: find.byType(Semantics)).first,
      );
      final numberRule = tester.widget<Semantics>(
        find.ancestor(of: find.text('One number'), matching: find.byType(Semantics)).first,
      );

      expect(lengthRule.properties.checked, isTrue);
      expect(numberRule.properties.checked, isFalse);
    });

    testWidgets('rejects a password without a number, without a round trip', (tester) async {
      final app = await openCreate(tester);

      await fill(tester, 'Name', 'Maya Okonkwo');
      await fill(tester, 'Email', 'maya@okonkwo.studio');
      await fill(tester, 'Password', 'abcdefgh');
      await tapText(tester, 'Create account');

      expect(find.text('Use at least 8 characters, including a number.'), findsOneWidget);
      expect(app.auth.registerCalls, 0);
    });

    testWidgets('creates the account, names it, and asks for verification', (tester) async {
      final app = await openCreate(tester);

      await fill(tester, 'Name', 'Maya Okonkwo');
      await fill(tester, 'Email', 'maya@okonkwo.studio');
      await fill(tester, 'Password', 'longer-pass-9');
      await tapText(tester, 'Create account');

      expect(app.auth.registeredName, 'Maya Okonkwo');
      expect(app.auth.verificationEmailsSent, 1);
      expect(find.text('One last step'.toUpperCase()), findsOneWidget);
      expect(app.profile.saves, 0, reason: 'opt-in is off by default, so nothing is written');
    });

    testWidgets('an opt-in is saved to the new account’s profile', (tester) async {
      final app = await openCreate(tester);

      await fill(tester, 'Name', 'Maya Okonkwo');
      await fill(tester, 'Email', 'maya@okonkwo.studio');
      await fill(tester, 'Password', 'longer-pass-9');
      await tester.ensureVisible(find.byType(EcCheckbox));
      await tester.tap(find.byType(EcCheckbox));
      await tester.pump();
      await tapText(tester, 'Create account');

      expect(app.profile.profile.marketingOptIn, isTrue);
    });
  });

  group('0.4 Reset password', () {
    testWidgets('carries the address over and shows the sent state on the same screen', (tester) async {
      final app = AppHarness.signedOut();
      await app.pump(tester);
      await tapText(tester, 'Sign in');
      await fill(tester, 'Email', 'maya@okonkwo.studio');
      await tapText(tester, 'Forgot password?');

      await tapText(tester, 'Send reset link');

      expect(app.auth.passwordResetSentTo, 'maya@okonkwo.studio');
      expect(find.text('Check your inbox'), findsOneWidget);
      expect(find.textContaining('If there’s an account for maya@okonkwo.studio'), findsOneWidget);
      expect(find.text('Resend in 1:00'), findsOneWidget);
    });

    testWidgets('Open Mail leaves for the Mail app', (tester) async {
      final app = AppHarness.signedOut();
      await app.pump(tester);
      await tapText(tester, 'Sign in');
      await fill(tester, 'Email', 'maya@okonkwo.studio');
      await tapText(tester, 'Forgot password?');
      await tapText(tester, 'Send reset link');

      await tapText(tester, 'Open Mail');

      expect(app.links.mailOpened, 1);
    });
  });

  group('0.5 Verify email', () {
    const unverified = AppUser(uid: 'u1', email: 'maya@okonkwo.studio', methods: {SignInMethod.password});

    testWidgets('gates an unverified email sign-up', (tester) async {
      await AppHarness(auth: FakeAuthRepository(initialUser: unverified)).pump(tester);

      expect(find.text('ONE LAST STEP'), findsOneWidget);
      expect(find.textContaining('maya@okonkwo.studio'), findsOneWidget);
      expect(_library, findsNothing);
    });

    testWidgets('Apple and Google accounts skip it', (tester) async {
      const apple = AppUser(uid: 'u2', methods: {SignInMethod.apple});
      await AppHarness(auth: FakeAuthRepository(initialUser: apple)).pump(tester);

      expect(_library, findsOneWidget);
    });

    testWidgets('moves on by itself once the link has been clicked', (tester) async {
      final app = AppHarness(auth: FakeAuthRepository(initialUser: unverified)..verifyOnReload = true);
      await app.pump(tester);

      await tester.pump(const Duration(seconds: 9));
      await tester.pumpAndSettle();

      expect(app.auth.reloadCalls, greaterThan(0));
      expect(_library, findsOneWidget);
    });

    testWidgets('resend sends another link, then cools down', (tester) async {
      final app = AppHarness(auth: FakeAuthRepository(initialUser: unverified));
      await app.pump(tester);

      await tapText(tester, 'Resend link');

      expect(app.auth.verificationEmailsSent, 1);
      expect(find.text('Resend link in 1:00'), findsOneWidget);
    });

    testWidgets('"Use a different email" deletes the empty account and starts over', (tester) async {
      final app = AppHarness(auth: FakeAuthRepository(initialUser: unverified));
      await app.pump(tester);

      await tapText(tester, 'Use a different email');

      expect(app.auth.deleted, isTrue);
      expect(find.text('Continue with Google'), findsOneWidget);
    });
  });

  testWidgets('signing out returns to the welcome screen', (tester) async {
    final app = AppHarness();
    await app.pump(tester);

    await app.auth.signOut();
    await tester.pumpAndSettle();

    expect(find.text('Continue with Google'), findsOneWidget);
  });
}
