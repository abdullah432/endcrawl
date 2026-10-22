import 'package:lastreel/core/result.dart';
import 'package:lastreel/data/repositories/auth_repository.dart';
import 'package:lastreel/domain/models/app_user.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
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

    testWidgets('Android retains its existing account connection options', (tester) async {
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
    expect(find.text('Yearly subscription'), findsOneWidget);
    expect(find.textContaining('nothing is deleted'), findsOneWidget);
  });

  testWidgets('help and support go to COOKOO', (tester) async {
    await openSettings(tester);
    await tapText(tester, 'Help centre');
    expect(app.links.opened, [Uri.parse('https://cookoo.dev/lastreel/help')]);

    await tapText(tester, 'Contact support');
    expect(app.links.composed, ['hello@cookoo.dev']);
  });

  group('7.4 privacy & data', () {
    // Skipped: the COOKOO Hide button and studio rows are hidden for now.
    testWidgets(skip: true, 'studio attribution identifies the app and placement', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Made by COOKOO');
      final uri = app.links.opened.single;
      expect(uri.host, 'cookoo.dev');
      expect(uri.queryParameters, {
        'utm_source': 'lastreel',
        'utm_medium': 'referral',
        'utm_campaign': 'made_by_cookoo',
        'utm_content': 'settings_footer',
      });
    });

    testWidgets('analytics is on by default; turning it off is saved and stops collection', (tester) async {
      await openSettings(tester);
      await tapText(tester, 'Privacy & data');

      expect(app.profile.profile.preferences.usageAnalytics, isTrue);
      expect(app.analytics.enabled, isTrue);

      await tapText(tester, 'Usage analytics');
      expect(app.profile.profile.preferences.usageAnalytics, isFalse);
      expect(app.analytics.enabled, isFalse);
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

    final verifyScreen = find.textContaining('your identity.', findRichText: true);
    final deletedScreen = find.text('ACCOUNT DELETED');

    Future<void> confirmDelete(WidgetTester tester) async {
      await openSettings(tester);
      await tapText(tester, 'Delete account');
      await tester.enterText(find.byType(TextField).first, 'DELETE');
      await tester.pumpAndSettle();
      await tapText(tester, 'Delete account permanently');
    }

    testWidgets('a Google account is told why before the Google sheet, and nothing goes until then', (tester) async {
      await confirmDelete(tester);

      expect(verifyScreen, findsOneWidget);
      expect(find.textContaining(testUser.email!, findRichText: true), findsOneWidget);
      expect(find.text('No need to start over'), findsOneWidget);
      expect(app.auth.reauthentications, 0);
      expect(app.projects.projects, hasLength(1));
      expect(app.auth.deleted, isFalse);
    });

    testWidgets('verifying deletes projects, profile, then the sign-in, and says so', (tester) async {
      await confirmDelete(tester);
      await tapText(tester, 'Continue with Google');

      expect(app.auth.reauthentications, 1);
      expect(app.projects.projects, isEmpty);
      expect(app.profile.deleted, isTrue);
      expect(app.auth.deleted, isTrue);
      expect(deletedScreen, findsOneWidget);

      await tapText(tester, 'Done');
      expect(deletedScreen, findsNothing);
      expect(find.text('Continue with Google'), findsOneWidget, reason: 'the welcome screen');
    });

    testWidgets('a failed provider revocation preserves projects, profile and login', (tester) async {
      await confirmDelete(tester);
      app.auth.prepareDeletionFailure = const AppFailure(FailureKind.network, 'Provider revocation unavailable.');
      await tapText(tester, 'Continue with Google');
      expect(app.auth.deletionPreparations, 1);
      expect(find.text('Provider revocation unavailable.'), findsOneWidget);
      expect(app.projects.projects, hasLength(1));
      expect(app.profile.deleted, isFalse);
      expect(app.auth.deleted, isFalse);
    });

    testWidgets('closing the Google sheet keeps everything and says so', (tester) async {
      await confirmDelete(tester);
      app.auth.failWith = cancelledByUser;
      await tapText(tester, 'Continue with Google');

      expect(find.text('Google sign-in was cancelled.'), findsOneWidget);
      expect(find.text('Your account hasn’t changed. Nothing was deleted.'), findsOneWidget);
      expect(find.text('Try again with Google'), findsOneWidget);
      expect(app.projects.projects, hasLength(1));
      expect(app.auth.deleted, isFalse);
    });

    testWidgets('if re-authentication fails, nothing is deleted and it can be tried again', (tester) async {
      await confirmDelete(tester);
      app.auth.failWith = const AppFailure(FailureKind.permission, 'That isn’t the account you’re signed in with.');
      await tapText(tester, 'Continue with Google');

      expect(find.text('We couldn’t verify it’s you.'), findsOneWidget);
      expect(find.text('That isn’t the account you’re signed in with.'), findsOneWidget);
      expect(app.projects.projects, hasLength(1));
      expect(app.profile.deleted, isFalse);
      expect(app.auth.deleted, isFalse);

      app.auth.failWith = null;
      await tapText(tester, 'Try again with Google');
      expect(app.auth.reauthentications, 2);
      expect(deletedScreen, findsOneWidget);
    });

    testWidgets('a failure after verifying is reported and leaves the sign-in', (tester) async {
      await confirmDelete(tester);
      app.projects.failWith = const AppFailure(FailureKind.network, 'No connection. Check your network and try again.');
      await tapText(tester, 'Continue with Google');

      expect(find.text('No connection. Check your network and try again.'), findsOneWidget);
      expect(app.auth.deleted, isFalse);
      expect(deletedScreen, findsNothing);
    });

    testWidgets('"Cancel and keep my account" goes back to Settings untouched', (tester) async {
      await confirmDelete(tester);
      await tapText(tester, 'Cancel and keep my account');

      expect(verifyScreen, findsNothing);
      expect(find.text('Delete account permanently'), findsNothing);
      expect(find.text('Settings'), findsOneWidget);
      expect(app.auth.reauthentications, 0);
      expect(app.auth.deleted, isFalse);
    });

    testWidgets('an email account confirms with its password, without 7.6b', (tester) async {
      app = AppHarness(
        auth: FakeAuthRepository(
          initialUser: const AppUser(
            uid: 'u1',
            email: 'maya@okonkwo.studio',
            isEmailVerified: true,
            methods: {SignInMethod.password},
          ),
        ),
      );
      await openSettings(tester);
      await tapText(tester, 'Delete account');
      await tester.enterText(find.byType(TextField).first, 'DELETE');
      await tester.enterText(find.byType(TextField).last, 'longer-pass-9');
      await tester.pumpAndSettle();
      await tapText(tester, 'Delete account permanently');

      expect(verifyScreen, findsNothing);
      expect(app.auth.reauthPassword, 'longer-pass-9');
      expect(app.auth.deleted, isTrue);
      expect(deletedScreen, findsOneWidget);
    });
  });
}
