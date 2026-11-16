import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/widgets/ec_button.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/library/screens/library_screen.dart';
import 'package:lastreel/features/plan/screens/pro_sheet.dart';
import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  const desktop = Size(1440, 900);
  testWidgets('Free web enters the normal app without preview or a paywall', (tester) async {
    final app = AppHarness(web: true, projects: FakeProjectRepository(seed: [film()]));
    await app.pump(tester, size: desktop);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.textContaining('previewing LastReel'), findsNothing);
    expect(find.text('Preview the app first'), findsNothing);
    expect(find.byType(ProSheet), findsNothing);
    await tester.tap(find.text('New project').first);
    await tester.pumpAndSettle();
    expect(find.text('Create project'), findsOneWidget);
    expect(find.text('Starting projects in the browser needs Pro.'), findsNothing);
  });
  testWidgets('Free web can edit existing projects', (tester) async {
    final app = AppHarness(web: true, projects: FakeProjectRepository(seed: [film()]));
    await app.pump(tester, size: desktop);
    await tester.tap(find.text('The Long Way Down').first);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(EcButton, 'Block'), findsOneWidget);
    expect(find.widgetWithText(EcButton, 'Paste'), findsOneWidget);
    expect(find.text('Read-only on the free plan'), findsNothing);
  });
  testWidgets('Pro web still enters the normal workspace', (tester) async {
    final app = AppHarness(web: true, plan: FakeEntitlementRepository(const Entitlement.pro()));
    await app.pump(tester, size: desktop);
    expect(find.byType(LibraryScreen), findsOneWidget);
    expect(find.byType(ProSheet), findsNothing);
    expect(find.text('Preview the app first'), findsNothing);
  });
}
