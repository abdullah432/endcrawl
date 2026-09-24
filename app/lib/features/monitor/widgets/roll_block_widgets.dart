import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../domain/models/credit_block.dart';
import '../../../domain/engine/roll_engine.dart';
import 'dotted_leader.dart';

/// Builds the actual visual content for one block, at full render
/// resolution — a straight port of the per-type styling in the
/// prototype's `rollModel()`. Hold cards are excluded (rendered as a
/// separate overlay, see `hold_overlay.dart`); spacers are just height.
Widget buildRollBlockContent(CreditBlock block, RollGeometry g) {
  final base = g.base;
  final face = g.face;
  TextStyle ctr(double size, {double opacity = 1, FontWeight weight = FontWeight.w400, double? spacing, double? height}) {
    return face.textStyle(size: size, weight: weight, letterSpacing: spacing, color: Colors.white.withValues(alpha: opacity)).copyWith(height: height);
  }

  Text line(String text, double size, {double opacity = 1, FontWeight weight = FontWeight.w400, double? spacing, double? height, FontStyle? style}) {
    final t = ctr(size, opacity: opacity, weight: weight, spacing: spacing, height: height);
    return Text(text, textAlign: TextAlign.center, style: style == null ? t : t.copyWith(fontStyle: style));
  }

  Widget header(String text) => line(text, base * .78, opacity: .62, spacing: base * .78 * .26);

  Widget column(List<Widget> children) => Column(mainAxisSize: MainAxisSize.min, children: children);

  switch (block) {
    case SpacerBlock v:
      return SizedBox(height: base * 2.2 * (v.seconds / 1.5));

    // A clear frame in the roll; the card itself is drawn by HoldOverlay
    // while the roll stops on it.
    case HoldBlock():
      return SizedBox(height: g.h);

    case TitleBlock v:
      return column([
        if (v.banner.isNotEmpty) ...[
          line(v.banner, base * .78, opacity: .72, spacing: base * .78 * .34),
          SizedBox(height: base * 1.6),
        ],
        line(v.title, base * v.titleScale, weight: FontWeight.w600, spacing: base * v.titleScale * .02, height: 1.06),
        if (v.byline.isNotEmpty) ...[
          SizedBox(height: base * 1.4),
          line(v.byline, base * .8, opacity: .78, spacing: base * .8 * .28),
        ],
      ]);

    case CardBlock v:
      return switch (v.kind) {
        // A section heading is a divider between runs of credits: larger
        // than a department header, no names under it.
        BlockKind.sectionHeading => line(v.header, base * 1.05, weight: FontWeight.w600, spacing: base * .2),
        BlockKind.quote => column([
            for (final l in v.lines) line(l, base * .95, opacity: .9, height: 1.45, style: FontStyle.italic),
            if (v.footer.isNotEmpty) ...[SizedBox(height: base * .6), line('— ${v.footer}', base * .78, opacity: .62)],
          ]),
        BlockKind.freeText || BlockKind.disclaimer => ConstrainedBox(
            constraints: BoxConstraints(maxWidth: g.w * .7),
            child: column([
              if (v.header.isNotEmpty) ...[header(v.header), SizedBox(height: base * .55)],
              for (final l in v.lines)
                line(l, base * (v.kind == BlockKind.disclaimer ? .62 : .82), opacity: .78, height: 1.5),
            ]),
          ),
        BlockKind.copyright => column([for (final l in v.lines) line(l, base * .7, opacity: .7, height: 1.6)]),
        _ => column([
            if (v.header.isNotEmpty) ...[header(v.header), SizedBox(height: base * .55)],
            for (final l in v.lines)
              line(l, base * (v.kind == BlockKind.presents ? .9 : 1.0), weight: FontWeight.w500, height: 1.42),
            if (v.footer.isNotEmpty) ...[SizedBox(height: base * .4), line(v.footer, base * .78, opacity: .62)],
          ]),
      };

    case MainCreditsBlock v:
      // Solo cards: each gets the frame to itself before the roll begins.
      return column([
        for (final (i, card) in v.cards.indexed) ...[
          if (i > 0) SizedBox(height: g.h * .45),
          header(card.header),
          SizedBox(height: base * .55),
          for (final n in card.names) line(n, base * 1.25, weight: FontWeight.w500, height: 1.35),
        ],
      ]);

    case NameListBlock v:
      final columns = v.columns > 0 ? v.columns : _autoColumns(v, g);
      final cols = _balanceColumns(v.names, columns);
      return column([
        header(v.header),
        SizedBox(height: base * (columns > 1 ? .8 : .55)),
        if (columns <= 1)
          for (final n in v.names)
            Padding(padding: EdgeInsets.only(bottom: base * .1), child: line(n, base, weight: FontWeight.w500, height: 1.42))
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cols.length; i++) ...[
                if (i > 0) SizedBox(width: base * 1.4),
                Flexible(
                  child: column([
                    for (final n in cols[i])
                      Padding(padding: EdgeInsets.only(bottom: base * .2), child: line(n, base * .84, opacity: .88, height: 1.5)),
                  ]),
                ),
              ],
            ],
          ),
      ]);

    case SongBlock v:
      return column([
        line(v.songTitle, base, weight: FontWeight.w500, height: 1.4),
        line(v.artist, base * .86, opacity: .8, height: 1.4),
        line(v.courtesy, base * .76, opacity: .6, height: 1.4, style: FontStyle.italic),
      ]);

    case MarkBlock v:
      final plateHeight = base * (v.kind == BlockKind.still ? 6 : 1.6);
      return column([
        Wrap(
          alignment: WrapAlignment.center,
          spacing: base * 1.6,
          runSpacing: base * .6,
          children: [
            for (final mark in v.marks)
              Container(
                height: plateHeight,
                constraints: BoxConstraints(minWidth: v.kind == BlockKind.still ? plateHeight * 1.6 : 0),
                alignment: Alignment.center,
                padding: EdgeInsets.symmetric(horizontal: base * .6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white.withValues(alpha: .3)),
                  borderRadius: BorderRadius.circular(base * .12),
                ),
                child: Text(mark, style: ctr(base * .62, opacity: .82, spacing: base * .62 * .2)),
              ),
          ],
        ),
        for (final l in v.lines) ...[SizedBox(height: base * .5), line(l, base * .7, opacity: .7)],
      ]);

    case DividerBlock v:
      return v.style == DividerStyle.rule
          ? Container(width: g.w * .12, height: 1, color: Colors.white.withValues(alpha: .4))
          : line('✦', base * .9, opacity: .6);

    case PairListBlock v:
      final cg = computeCastGeometry(v, g);
      return column([
        header(v.header),
        SizedBox(height: base * .9),
        for (final r in v.rows) _castRow(r, g, cg, v.leader, ctr),
      ]);
  }
}

/// One column for a short list, more as it grows and as the canvas allows —
/// a tall 9:16 frame never gets more than two.
int _autoColumns(NameListBlock block, RollGeometry g) {
  if (block.kind == BlockKind.department && block.names.length < 6) return 1;
  if (block.names.length < 6) return 1;
  return g.tall ? 2 : 3;
}

Widget _castRow(
  CastRow r,
  RollGeometry g,
  CastGeometry cg,
  LeaderStyle leader,
  TextStyle Function(double, {double opacity, FontWeight weight, double? spacing, double? height}) ctr,
) {
  final base = g.base;

  if (r is GapCastRow) return SizedBox(height: base * .9);

  if (r is SpanCastRow) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: base * .35),
      child: Text(r.text, textAlign: TextAlign.center, style: ctr(base * .82, opacity: .66, spacing: base * .82 * .22)),
    );
  }

  final pair = r as PairCastRow;

  if (cg.collapse) {
    return Padding(
      padding: EdgeInsets.only(bottom: base * .78),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(pair.role, textAlign: TextAlign.center, style: ctr(base * .74, opacity: .6, spacing: base * .74 * .14, height: 1.3)),
          Text(pair.actor, textAlign: TextAlign.center, style: ctr(base, weight: FontWeight.w500, height: 1.3)),
        ],
      ),
    );
  }

  return Padding(
    padding: EdgeInsets.only(bottom: base * .5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: cg.colWidth,
          child: Text(
            pair.role,
            textAlign: TextAlign.right,
            style: ctr(base, opacity: .82, height: 1.32),
          ),
        ),
        SizedBox(
          width: cg.gutter,
          height: base * .9,
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: base * .3),
            child: switch (leader) {
              LeaderStyle.dots => CustomPaint(
                  painter: DottedLeaderPainter(
                    dotSpacing: base * .36,
                    dotRadius: (base * .045).clamp(1, double.infinity),
                    baselineFromBottom: base * .28,
                  ),
                ),
              LeaderStyle.rule => Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(margin: EdgeInsets.only(bottom: base * .28), height: 1, color: Colors.white.withValues(alpha: .28)),
                ),
              LeaderStyle.clean => const SizedBox.shrink(),
            },
          ),
        ),
        SizedBox(
          width: cg.colWidth,
          child: Text(
            pair.actor,
            textAlign: TextAlign.left,
            style: ctr(base, weight: FontWeight.w500, height: 1.32),
          ),
        ),
      ],
    ),
  );
}

List<List<String>> _balanceColumns(List<String> names, int columns) {
  if (columns <= 1 || names.isEmpty) return [names];
  final perCol = (names.length / columns).ceil();
  final cols = <List<String>>[];
  for (var i = 0; i < names.length; i += perCol) {
    cols.add(names.sublist(i, i + perCol > names.length ? names.length : i + perCol));
  }
  return cols;
}
