import 'package:lastreel/core/result.dart';
import 'package:lastreel/domain/models/app_user.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  late AppHarness app;

  setUp(() => app = AppHarness(projects: FakeProjectRepository(seed: [film()])));

  Future<void> tapText(WidgetTester tester, String text) async {
    final finder = find.text(text).last;
    await tester.ensureVisible(finder);
    await tester.pumpAndSettle();
    await tester.tap(finder);
    await tester.pumpAndSettle();
  }

  Future<void> openSettings(WidgetTester tester) async {
    await app.pump(tester);
    await tester.tap(find.bySemanticsLabel('Account').first);
    await tester.pumpAndSettle();
  }

  group('7.2 profile', () {
    testWidgets('renames the account', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Mara Oyelaran');

      expect(find.text('Profile'), findsOneWidget);
      expect(find.text('VERIFIED'), findsOneWidget);

      await tester.enterText(find.widgetWithText(TextField, 'Mara Oyelaran'), 'Mara O.');
      await tester.pumpAndSettle();
      await tapText(tester, 'Save');

      expect(app.auth.currentUser?.displayName, 'Mara O.');
      expect(find.text('Profile saved'), findsOneWidget);
    });

    testWidgets('the only sign-in method cannot be removed', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Mara Oyelaran');

      await tapText(tester, 'Google');

      expect(find.textContaining('You always need at least one way to sign in'), findsWidgets);
      expect(app.auth.currentUser?.methods, {SignInMethod.google});
    });

    testWidgets('Apple is not offered while it is switched off', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Mara Oyelaran');

      expect(find.text('Apple'), findsNothing);
      expect(find.text('Sign in without Google'), findsOneWidget);
    });

    testWidgets('adding email & password lets Google be disconnected', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Mara Oyelaran');

      await tapText(tester, 'Email & password');
      await tester.enterText(find.byType(TextField).last, 'longpass1');
      await tester.pumpAndSettle();
      await tapText(tester, 'Connect');
      expect(find.text('CONNECTED'), findsNWidgets(2));

      await tapText(tester, 'Google');
      expect(find.text('Disconnect Google?'), findsOneWidget);
      await tapText(tester, 'Disconnect');

      expect(app.auth.currentUser?.methods, {SignInMethod.password});
    });

    testWidgets('sets up email & password for a Google account', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Mara Oyelaran');

      await tapText(tester, 'Email & password');
      await tester.enterText(find.byType(TextField).last, 'longpass1');
      await tester.pumpAndSettle();
      await tapText(tester, 'Connect');

      expect(app.auth.currentUser?.methods, contains(SignInMethod.password));
    });
  });

  testWidgets('7.3 Pro opens its subscription from the plan card', (tester) async {
    app = AppHarness(
      projects: FakeProjectRepository(seed: [film()]),
      plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly)),
    );
    await openSettings(tester);

    await tapText(tester, 'LastReel Pro');

    expect(find.text('Subscription'), findsOneWidget);
    expect(find.text('Unlimited · 1 in use'), findsOneWidget);
    expect(find.text('Yearly · \$29.99'), findsOneWidget);
    expect(find.textContaining('nothing is deleted'), findsOneWidget);
  });

  group('7.4 privacy & data', () {
    testWidgets('choices are saved to the account; analytics starts off', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Privacy & data');

      expect(app.profile.profile.preferences.usageAnalytics, isFalse);
      await tapText(tester, 'Usage analytics');
      expect(app.profile.profile.preferences.usageAnalytics, isTrue);
    });

    testWidgets('data export says it is coming', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Privacy & data');
      await tapText(tester, 'Download my data');
      expect(find.text('Data export is coming soon'), findsOneWidget);
    });
  });

  group('7.6 delete account', () {
    testWidgets('lists what goes and waits for DELETE', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Delete account');

      expect(find.textContaining('1 project and 0 renders'), findsOneWidget);
      expect(find.text('Deleting doesn’t cancel a subscription.'), findsOneWidget);

      await tapText(tester, 'Delete account permanently');
      expect(app.auth.deleted, isFalse, reason: 'disabled until DELETE is typed');
    });

    testWidgets('deletes projects, profile, then the sign-in, and returns to welcome', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Delete account');

      await tester.enterText(find.byType(TextField).first, 'DELETE');
      await tester.pumpAndSettle();
      await tapText(tester, 'Delete account permanently');

      expect(app.auth.reauthentications, 1);
      expect(app.projects.projects, isEmpty);
      expect(app.profile.deleted, isTrue);
      expect(app.auth.deleted, isTrue);
      expect(find.text('Account deleted'), findsOneWidget);
      expect(find.text('Continue with Google'), findsOneWidget);
    });

    testWidgets('if re-authentication fails, nothing is deleted', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Delete account');
      app.auth.failWith = const AppFailure(FailureKind.permission, 'Sign in again to continue.');

      await tester.enterText(find.byType(TextField).first, 'DELETE');
      await tester.pumpAndSettle();
      await tapText(tester, 'Delete account permanently');

      expect(app.projects.projects, hasLength(1));
      expect(app.profile.deleted, isFalse);
      expect(app.auth.deleted, isFalse);
      expect(find.text('Sign in again to continue.'), findsOneWidget);
    });
  });
}
