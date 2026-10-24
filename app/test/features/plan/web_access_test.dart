import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/export/controllers/export_controller.dart';
import 'package:lastreel/features/plan/controllers/web_access.dart';
import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  testWidgets(
    'Free web is visible but operations are blocked; verified Pro unlocks it',
    (tester) async {
      final plan = FakeEntitlementRepository();
      final app = AppHarness(
        plan: plan,
        projects: FakeProjectRepository(seed: [film()]),
        web: true,
      );
      await app.pump(tester, size: const Size(1440, 900));
      expect(find.text('The Long Way Down'), findsOneWidget);
      expect(find.textContaining('Preview · Pro required'), findsNothing);
      final scope = ProviderScope.containerOf(
        tester.element(find.text('Projects').first),
      );
      expect(scope.read(webAccessAllowedProvider), isFalse);
      expect(scope.read(exportControllerProvider.notifier).start(), isFalse);
      expect(app.encoder.started, isEmpty);
      plan.entitlement = const Entitlement.pro();
      await tester.pumpAndSettle();
      expect(scope.read(webAccessAllowedProvider), isTrue);
      await tester.tap(find.text('The Long Way Down'));
      await tester.pumpAndSettle();
      plan.entitlement = const Entitlement.free(lapsed: true);
      await tester.pumpAndSettle();
      expect(scope.read(webAccessAllowedProvider), isFalse);
      expect(scope.read(exportControllerProvider.notifier).start(), isFalse);
    },
  );
}
