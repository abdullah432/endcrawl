import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/widgets/ec_chip.dart';
import '../../../core/widgets/ec_fields.dart';
import '../../../core/widgets/ec_stepper.dart';
import '../../../core/widgets/ec_surfaces.dart';
import '../../../domain/models/credit_block.dart';
import '../../project/controllers/project_controller.dart';

/// The fields of every block kind except cast and crew lists, which have
/// their own editor. One form per shape, so the 27 kinds need nine.
class GenericBlockEditor extends ConsumerWidget {
  final CreditBlock block;
  const GenericBlockEditor({super.key, required this.block});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(projectControllerProvider.notifier);
    final id = block.id;

    void patch<T extends CreditBlock>(String field, T Function(T) fn) =>
        controller.patchBlock(id, (b) => fn(b as T), field: field);

    Widget text(String label, String value, String field, CreditBlock Function(String) apply, {String? hint}) =>
        _BoundField(key: ValueKey('$id/$field'), label: label, value: value, hint: hint, onChanged: (v) => controller.patchBlock(id, (_) => apply(v), field: field));

    Widget lines(String label, List<String> value, String field, CreditBlock Function(List<String>) apply, {String? hint}) =>
        _BoundArea(
          key: ValueKey('$id/$field'),
          label: label,
          value: value.join('\n'),
          hint: hint,
          onChanged: (v) => controller.patchBlock(id, (_) => apply(v.split('\n')), field: field),
        );

    Widget seconds(String label, double value, double step, CreditBlock Function(double) apply, {double min = 0}) => _Labelled(
          label: label,
          child: EcStepper(
            display: '${value.toStringAsFixed(value == value.roundToDouble() ? 0 : 2)}s',
            onDec: value - step < min ? null : () => controller.patchBlock(id, (_) => apply(value - step)),
            onInc: () => controller.patchBlock(id, (_) => apply(value + step)),
          ),
        );

    final fields = switch (block) {
      TitleBlock v => [
          text('Banner', v.banner, 'banner', (s) => v.copyWith(banner: s), hint: 'A production company'),
          text('Film title', v.title, 'title', (s) => v.copyWith(title: s)),
          text('Byline', v.byline, 'byline', (s) => v.copyWith(byline: s), hint: 'A film by'),
          _Labelled(
            label: 'Title size',
            child: EcStepper(
              display: '${v.titleScale.toStringAsFixed(1)}×',
              onDec: v.titleScale <= 1 ? null : () => patch<TitleBlock>('scale', (b) => b.copyWith(titleScale: v.titleScale - .1)),
              onInc: v.titleScale >= 4 ? null : () => patch<TitleBlock>('scale', (b) => b.copyWith(titleScale: v.titleScale + .1)),
            ),
          ),
        ],
      CardBlock v when v.kind == BlockKind.sectionHeading => [
          text('Heading', v.header, 'header', (s) => v.copyWith(header: s), hint: 'Second unit'),
        ],
      CardBlock v => [
          text('Header', v.header, 'header', (s) => v.copyWith(header: s)),
          lines('Lines · one per line', v.lines, 'lines', (l) => v.copyWith(lines: l)),
          if (v.kind == BlockKind.quote || v.kind == BlockKind.freeText || v.footer.isNotEmpty)
            text(v.kind == BlockKind.quote ? 'Attribution' : 'Footer', v.footer, 'footer', (s) => v.copyWith(footer: s)),
        ],
      MainCreditsBlock v => [
          lines(
            'Cards · "Header: Name, Name" per line',
            [for (final c in v.cards) c.header.isEmpty ? c.names.join(', ') : '${c.header}: ${c.names.join(', ')}'],
            'cards',
            (l) => v.copyWith(cards: [for (final line in l) if (line.trim().isNotEmpty) _parseCard(line)]),
          ),
        ],
      NameListBlock v => [
          text('Header', v.header, 'header', (s) => v.copyWith(header: s)),
          lines('Names · one per line', v.names, 'names', (l) => v.copyWith(names: l)),
          _Labelled(
            label: 'Columns',
            child: EcSegmented(
              labels: const ['One', 'Two', 'Three'],
              selectedIndex: (v.columns - 1).clamp(0, 2),
              onChanged: (i) => patch<NameListBlock>('columns', (b) => b.copyWith(columns: i + 1)),
            ),
          ),
        ],
      SongBlock v => [
          text('Song', v.songTitle, 'song', (s) => v.copyWith(songTitle: s)),
          text('Written and performed by', v.artist, 'artist', (s) => v.copyWith(artist: s)),
          text('Courtesy of', v.courtesy, 'courtesy', (s) => v.copyWith(courtesy: s)),
        ],
      MarkBlock v => [
          const EcNotice(
            tone: EcTone.neutral,
            icon: Icons.image_outlined,
            title: 'Marks are text for now',
            body: 'Type each logo’s name; image upload is coming soon.',
          ),
          lines('Marks · one per line', v.marks, 'marks', (l) => v.copyWith(marks: l)),
          lines('Lines under the marks', v.lines, 'lines', (l) => v.copyWith(lines: l)),
        ],
      HoldBlock v => [
          lines('Card lines', v.lines, 'lines', (l) => v.copyWith(lines: l)),
          seconds('Hold', v.hold, .5, (n) => v.copyWith(hold: n), min: .5),
          seconds('Fade in', v.fadeIn, .25, (n) => v.copyWith(fadeIn: n)),
          seconds('Fade out', v.fadeOut, .25, (n) => v.copyWith(fadeOut: n)),
        ],
      SpacerBlock v => [seconds('Gap', v.seconds, .25, (n) => v.copyWith(seconds: n), min: .25)],
      DividerBlock v => [
          _Labelled(
            label: 'Style',
            child: EcSegmented(
              labels: const ['Thin rule', 'Ornament'],
              selectedIndex: v.style.index,
              onChanged: (i) => patch<DividerBlock>('style', (b) => b.copyWith(style: DividerStyle.values[i])),
            ),
          ),
        ],
      PairListBlock() => const <Widget>[],
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in fields) ...[f, const SizedBox(height: 14)],
      ],
    );
  }

  static CreditEntry _parseCard(String line) {
    final colon = line.indexOf(':');
    List<String> names(String s) => s.split(',').map((n) => n.trim()).where((n) => n.isNotEmpty).toList();
    if (colon < 0) return CreditEntry(names: names(line));
    return CreditEntry(header: line.substring(0, colon).trim(), names: names(line.substring(colon + 1)));
  }
}

class _Labelled extends StatelessWidget {
  final String label;
  final Widget child;
  const _Labelled({required this.label, required this.child});

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [Text(label, style: context.type.label), const SizedBox(height: 7), child],
      );
}

/// An [EcTextField] that owns its controller, seeded once from the block —
/// the block updates on every keystroke, so re-seeding would fight the
/// caret.
class _BoundField extends StatefulWidget {
  final String label;
  final String value;
  final String? hint;
  final ValueChanged<String> onChanged;

  const _BoundField({super.key, required this.label, required this.value, this.hint, required this.onChanged});

  @override
  State<_BoundField> createState() => _BoundFieldState();
}

class _BoundFieldState extends State<_BoundField> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => EcTextField(
        controller: _controller,
        label: widget.label,
        hint: widget.hint,
        textCapitalization: TextCapitalization.words,
        onChanged: widget.onChanged,
      );
}

class _BoundArea extends StatefulWidget {
  final String label;
  final String value;
  final String? hint;
  final ValueChanged<String> onChanged;

  const _BoundArea({super.key, required this.label, required this.value, this.hint, required this.onChanged});

  @override
  State<_BoundArea> createState() => _BoundAreaState();
}

class _BoundAreaState extends State<_BoundArea> {
  late final _controller = TextEditingController(text: widget.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      EcTextArea(controller: _controller, label: widget.label, hint: widget.hint, onChanged: widget.onChanged);
}
