import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/features.dart';
import 'package:lastreel/data/repositories/auth_repository.dart';
import 'package:lastreel/domain/models/app_user.dart';
import 'package:lastreel/features/library/screens/library_screen.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';

void main() {
  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);
  Future<void> tap(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.tap(find.text(text).last);
    await tester.pumpAndSettle();
  }

  for (final size in [
    const Size(393, 852),
    const Size(844, 390),
    const Size(834, 1194),
    const Size(1194, 834),
  ]) {
    testWidgets('Apple and Google are offered equally on $size', (
      tester,
    ) async {
      await AppHarness.signedOut().pump(tester, size: size);
      expect(Features.appleSignIn, isTrue);
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tap(tester, 'Sign in');
      expect(find.text('Continue with Apple'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }, variant: ios);
  }

  testWidgets(
    'Apple signs in from welcome with a private email and reaches projects',
    (tester) async {
      final app = AppHarness.signedOut();
      await app.pump(tester);
      await tap(tester, 'Continue with Apple');
      expect(app.auth.signInWithAppleCalls, 1);
      expect(
        app.auth.currentUser?.email,
        endsWith('@privaterelay.appleid.com'),
      );
      expect(app.auth.currentUser?.needsEmailVerification, isFalse);
      expect(find.byType(LibraryScreen), findsOneWidget);
    },
    variant: ios,
  );

  testWidgets('email sign-in also offers Apple; closing its sheet is silent', (
    tester,
  ) async {
    final app = AppHarness(
      auth: FakeAuthRepository()..failWith = cancelledByUser,
    );
    await app.pump(tester);
    await tap(tester, 'Sign in');
    await tap(tester, 'Continue with Apple');
    expect(app.auth.signInWithAppleCalls, 1);
    expect(find.text('Sign-in cancelled.'), findsNothing);
    expect(find.text('Continue with Apple'), findsOneWidget);
  }, variant: ios);

  testWidgets(
    'linking Apple requires explicit consent and Cancel changes nothing',
    (tester) async {
      final app = AppHarness();
      await app.pump(tester);
      await tester.tap(find.bySemanticsLabel('Account').first);
      await tester.pumpAndSettle();
      await tap(tester, 'Mara Oyelaran');
      await tap(tester, 'Apple');
      expect(find.text('Connect Apple?'), findsOneWidget);
      expect(app.auth.currentUser?.methods, {SignInMethod.google});
      await tap(tester, 'Cancel');
      expect(app.auth.currentUser?.methods, {SignInMethod.google});
      await tap(tester, 'Apple');
      await tap(tester, 'Continue');
      expect(app.auth.currentUser?.methods, {
        SignInMethod.google,
        SignInMethod.apple,
      });
    },
    variant: ios,
  );

  testWidgets(
    'Android retains its existing Google and email sign-in options',
    (tester) async {
      await AppHarness.signedOut().pump(tester);
      expect(Features.appleSignIn, isFalse);
      expect(find.text('Continue with Apple'), findsNothing);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.android),
  );
}
