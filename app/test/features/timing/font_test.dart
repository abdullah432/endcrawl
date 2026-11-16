import 'dart:io';
import 'package:flutter/services.dart';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lastreel/domain/models/credit_face.dart';
import 'package:lastreel/domain/models/project_settings.dart';
import 'package:lastreel/features/project/controllers/project_controller.dart';
import 'package:lastreel/features/timing/screens/font_sheet.dart';
import '../../support/app_harness.dart';
import '../../support/fake_project_repository.dart';
import '../../support/fixtures.dart';

void main() {
  for (final size in [const Size(375, 812), const Size(1024, 768)]) {
    testWidgets('font selection persists without changing credits at $size', (
      tester,
    ) async {
      final app = AppHarness(projects: FakeProjectRepository(seed: [film()]));
      if (const bool.fromEnvironment('CAPTURE_UX')) {
        await tester.runAsync(() async {
          final loader = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await loader.load();
        });
      }
      await app.pump(tester, size: size);
      await tester.tap(find.text('The Long Way Down'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Font'));
      await tester.pumpAndSettle();
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      expect(find.byType(FontSheet), findsOneWidget);
      final container = ProviderScope.containerOf(
        tester.element(find.byType(FontSheet)),
      );
      final before = container.read(projectControllerProvider);
      await tester.tap(find.text(CreditFace.serif.displayName));
      await tester.pumpAndSettle();
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
      final after = container.read(projectControllerProvider);
      expect(after.face, CreditFace.serif);
      expect(after.blocks, before.blocks);
      expect(after.settings.fps, before.settings.fps);
      expect(after.settings.ppf, before.settings.ppf);
      expect(
        app.projects.projects.values.single.settings.face,
        CreditFace.serif,
      );
      expect(
        ProjectSettings.fromJson(after.settings.toJson()).face,
        CreditFace.serif,
      );
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('CAPTURE_UX') && size.width == 375) {
        await tester.runAsync(() async {
          final view = tester.binding.renderViews.first;
          final layer = view.debugLayer! as OffsetLayer;
          final image = layer.toImageSync(Offset.zero & view.size, pixelRatio: 2);
          final data = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '../output/ux-audit/04-font-picker-after.png',
          ).writeAsBytes(data!.buffer.asUint8List());
          image.dispose();
        });
      }
    });
  }
}
