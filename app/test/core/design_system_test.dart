import 'package:lastreel/core/theme/app_theme.dart';
import 'package:lastreel/core/theme/ec_palette.dart';
import 'package:lastreel/core/theme/theme_context.dart';
import 'package:lastreel/core/widgets/ec_button.dart';
import 'package:lastreel/core/widgets/ec_chip.dart';
import 'package:lastreel/core/widgets/ec_fields.dart';
import 'package:lastreel/core/widgets/ec_settings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _host(Widget child) => MaterialApp(
      theme: buildLastReelTheme(),
      home: Scaffold(body: Center(child: Padding(padding: const EdgeInsets.all(16), child: child))),
    );

void main() {
  testWidgets('palette and type resolve from the theme', (tester) async {
    late EcPalette palette;
    late double displaySize;
    await tester.pumpWidget(_host(Builder(builder: (context) {
      palette = context.palette;
      displaySize = context.type.displayXL.fontSize!;
      return const SizedBox();
    })));

    expect(palette.ground, const Color(0xFFF4EEE5));
    expect(displaySize, 52);
  });

  testWidgets('a widget pumped without the theme still gets the light palette', (tester) async {
    late EcPalette palette;
    await tester.pumpWidget(Builder(builder: (context) {
      palette = context.palette;
      return const SizedBox();
    }));

    expect(palette, same(EcPalette.light));
  });

  testWidgets('a busy button ignores taps and keeps its height', (tester) async {
    var taps = 0;
    await tester.pumpWidget(_host(EcButton(label: 'Sign in', onPressed: () => taps++)));
    final restHeight = tester.getSize(find.byType(EcButton)).height;

    await tester.pumpWidget(_host(EcButton(label: 'Sign in', busy: true, onPressed: () => taps++)));
    await tester.tap(find.byType(EcButton));

    expect(taps, 0);
    expect(tester.getSize(find.byType(EcButton)).height, restHeight);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('a text field shows its error underneath', (tester) async {
    await tester.pumpWidget(_host(EcTextField(
      controller: TextEditingController(),
      label: 'Password',
      error: 'That password doesn’t match this email.',
    )));

    expect(find.text('That password doesn’t match this email.'), findsOneWidget);
  });

  testWidgets('the password field toggles between Show and Hide', (tester) async {
    await tester.pumpWidget(_host(EcPasswordField(controller: TextEditingController(text: 'secret1'))));

    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isTrue);
    await tester.tap(find.text('Show'));
    await tester.pump();

    expect(tester.widget<TextField>(find.byType(TextField)).obscureText, isFalse);
    expect(find.text('Hide'), findsOneWidget);
  });

  testWidgets('a long chip label ellipsises instead of overflowing', (tester) async {
    await tester.pumpWidget(_host(SizedBox(
      width: 80,
      child: EcChip(label: 'ProRes 4444 with alpha channel', selected: true, onTap: () {}),
    )));

    expect(tester.takeException(), isNull);
  });

  testWidgets('segmented control reports the tapped index', (tester) async {
    int? picked;
    await tester.pumpWidget(_host(EcSegmented(
      labels: const ['Lock runtime', 'Lock speed'],
      selectedIndex: 0,
      onChanged: (i) => picked = i,
    )));

    await tester.tap(find.text('Lock speed'));
    expect(picked, 1);
  });

  testWidgets('tapping a toggle row flips the switch', (tester) async {
    bool? value;
    await tester.pumpWidget(_host(EcGroup(label: 'App', children: [
      EcGroupRow.toggle(title: 'Haptics', value: false, onChanged: (v) => value = v),
    ])));

    await tester.tap(find.text('Haptics'));
    expect(value, isTrue);
  });
}
