import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/widgets/ec_fields.dart';
import 'package:lastreel/domain/models/entitlement.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  const text = 'Renny — Sofia Alvarez\nYoung Renny Cleo Barr\nNurse — Lucia Ferrante';

  AppHarness pro() => AppHarness(
    projects: FakeProjectRepository(seed: [film()]),
    plan: FakeEntitlementRepository(const Entitlement.pro(period: BillingPeriod.yearly)),
  );

  Future<void> openPaste(WidgetTester tester, Size size) async {
    await pro().pump(tester, size: size);
    await tester.tap(find.text('The Long Way Down').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cast · two column').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Paste').first);
    await tester.pumpAndSettle();
    await tester.enterText(raw, text);
    await tester.pumpAndSettle();
  }

  final alert = find.textContaining('has no separator.', findRichText: true);

  for (final (name, size) in [('T4.2 landscape', const Size(1194, 834)), ('P4.2 portrait', const Size(834, 1194))]) {
    group(name, () {
      testWidgets('the line that won’t split gets its own alert, never a guess', (tester) async {
        await openPaste(tester, size);
        expect(find.text('Paste & split'), findsOneWidget);
        expect(find.text('Paste'), findsWidgets);
        expect(find.text('Import file'), findsOneWidget);
        expect(find.text('RAW · 3 LINES'), findsOneWidget);
        expect(find.text('STRUCTURED · 2 ROWS'), findsOneWidget);
        expect(find.text('1 NEEDS A LOOK'), findsOneWidget);
        expect(alert, findsOneWidget);
        expect(tester.widget<EcTextArea>(find.byType(EcTextArea)).flaggedLines, {1});
        expect(find.text('Add 2 rows'), findsOneWidget);
        // "2+ spaces" splits nothing here, so it isn't offered.
        expect(find.textContaining('2+ spaces'), findsNothing);
        expect(tester.takeException(), isNull);
      });

      testWidgets('Edit line puts the caret on it in the raw text', (tester) async {
        await openPaste(tester, size);
        await tester.ensureVisible(find.text('Edit line'));
        await tester.tap(find.text('Edit line'));
        await tester.pumpAndSettle();
        final field = tester.widget<TextField>(raw);
        final selection = field.controller!.selection;
        expect(field.controller!.text.substring(selection.start, selection.end), 'Young Renny Cleo Barr');
        expect(field.focusNode!.hasFocus, isTrue);
      });

      testWidgets('Skip leaves it out', (tester) async {
        await openPaste(tester, size);
        await tester.ensureVisible(find.text('Skip'));
        await tester.tap(find.text('Skip'));
        await tester.pumpAndSettle();
        expect(alert, findsNothing);
        expect(find.text('1 NEEDS A LOOK'), findsNothing);
        expect(find.text('Add 2 rows'), findsOneWidget);
      });
    });
  }
}

final raw = find.descendant(of: find.byType(EcTextArea), matching: find.byType(TextField));
