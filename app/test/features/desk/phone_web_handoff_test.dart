import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/app_links.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/access/screens/web_access_screen.dart';
import 'package:lastreel/features/desk/bigger_screens_page.dart';

import '../../support/app_harness.dart';
import '../../support/fake_auth_repository.dart';
import '../../support/fake_entitlement_repository.dart';

void main() {
  for (final pro in [false, true]) {
    testWidgets(
      '${pro ? 'Pro' : 'Free'} phone sign-in opens the computer handoff',
      (tester) async {
        final app = AppHarness(
          web: true,
          auth: FakeAuthRepository(),
          plan: pro ? FakeEntitlementRepository(const Entitlement.pro()) : null,
        );
        await app.pump(tester);
        await tester.ensureVisible(find.text('Continue with Google'));
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        expect(app.auth.signInWithGoogleCalls, 1);
        expect(find.byType(BiggerScreensPage), findsOneWidget);
        expect(find.byType(WebAccessScreen), findsNothing);
        expect(find.text('Email me this link'), findsOneWidget);
        expect(find.text('Copy link'), findsOneWidget);
        expect(find.text('Sends to ${testUser.email}'), findsOneWidget);
      },
    );
  }

  testWidgets('a pushed access screen shows the phone handoff when narrowed', (
    tester,
  ) async {
    final app = AppHarness(web: true);
    await app.pump(tester, size: const Size(1440, 900));
    await tester.tap(find.text('Preview the app first'));
    await tester.pumpAndSettle();
    final context = tester.element(find.byType(Navigator).first);
    WebAccessScreen.open(context);
    await tester.pumpAndSettle();
    expect(
      find.text('Your credits, at a desk.', findRichText: true),
      findsOneWidget,
    );

    tester.view.physicalSize = AppHarness.phone;
    await tester.pumpAndSettle();
    expect(find.byType(BiggerScreensPage), findsOneWidget);
    expect(find.text('Preview the app first'), findsNothing);
    expect(find.text('Email me this link'), findsOneWidget);
    expect(find.text('Copy link'), findsOneWidget);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(find.byType(BiggerScreensPage), findsNothing);
    expect(find.text('Preview the app first'), findsOneWidget);
  });

  testWidgets('Free desktop access swaps to phone handoff when narrowed', (
    tester,
  ) async {
    final app = AppHarness(web: true);
    await app.pump(tester, size: const Size(1440, 900));
    expect(find.byType(WebAccessScreen), findsOneWidget);

    tester.view.physicalSize = AppHarness.phone;
    await tester.pumpAndSettle();
    expect(find.byType(BiggerScreensPage), findsOneWidget);
    expect(find.byType(WebAccessScreen), findsNothing);

    final copied = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copied.add((call.arguments as Map)['text'] as String);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.ensureVisible(find.text('Copy link'));
    await tester.tap(find.text('Copy link'));
    await tester.pumpAndSettle();
    expect(copied, [AppLinks.webApp.toString()]);

    tester.view.physicalSize = const Size(1440, 900);
    await tester.pumpAndSettle();
    expect(find.byType(WebAccessScreen), findsOneWidget);
    expect(app.auth.currentUser?.uid, testUser.uid);
  });
}
