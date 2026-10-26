import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lastreel/core/config/app_platform.dart';
import 'package:lastreel/domain/models/entitlement.dart';
import 'package:lastreel/features/access/controllers/web_access.dart';
import 'package:lastreel/features/export/controllers/export_controller.dart';
import 'package:lastreel/features/home/tablet_layout.dart';
import 'package:lastreel/features/plan/controllers/web_access.dart';

import '../../support/app_harness.dart';
import '../../support/fake_entitlement_repository.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  test('macOS uses verified workspace access, never mobile rules', () {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    addTearDown(() => debugDefaultTargetPlatformOverride = null);
    expect(AppPlatform.isNativeDesktop, isTrue);
    expect(AppPlatform.requiresVerifiedPro, isTrue);
    expect(AppPlatform.isMobile, isFalse);
  });

  testWidgets(
    'native Free preview rejects exports and responds to plan expiry',
    (tester) async {
      final plan = FakeEntitlementRepository();
      final app = AppHarness(
        plan: plan,
        projects: FakeProjectRepository(seed: [film()]),
        testerAllowed: true,
      );
      // A mobile tester toggle must not grant desktop access.
      await app.testerMode.setProOn(true);
      await app.pump(tester, size: const Size(1440, 900));
      expect(find.text('Projects'), findsWidgets);
      final scope = ProviderScope.containerOf(
        tester.element(find.text('Projects').first),
      );
      expect(scope.read(runningOnWebProvider), isFalse);
      expect(scope.read(verifiedWorkspaceProvider), isTrue);
      expect(scope.read(webPreviewProvider), isTrue);
      expect(scope.read(webAccessAllowedProvider), isFalse);
      expect(scope.read(exportControllerProvider.notifier).start(), isFalse);
      expect(app.encoder.started, isEmpty);

      plan.entitlement = const Entitlement.pro();
      await tester.pumpAndSettle();
      expect(scope.read(webAccessAllowedProvider), isTrue);
      await tester.tap(find.text('The Long Way Down').first);
      await tester.pumpAndSettle();
      plan.entitlement = const Entitlement.free(lapsed: true);
      await tester.pumpAndSettle();
      expect(scope.read(webAccessAllowedProvider), isFalse);
      expect(scope.read(exportControllerProvider.notifier).start(), isFalse);
      expect(app.encoder.started, isEmpty);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );

  testWidgets(
    'a smaller Mac window keeps desktop navigation',
    (tester) async {
      final app = AppHarness(
        plan: FakeEntitlementRepository(const Entitlement.pro()),
      );
      await app.pump(tester, size: const Size(1000, 700));
      final context = tester.element(find.text('Projects').first);
      expect(context.tabletLayout, isNull);
      expect(tester.takeException(), isNull);
    },
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
  );
}
