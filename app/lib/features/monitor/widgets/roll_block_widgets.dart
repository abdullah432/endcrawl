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

  switch (block) {
    case SpacerBlock v:
      return SizedBox(height: base * 2.2 * (v.seconds / 1.5));

    case HoldBlock():
      return const SizedBox.shrink();

    case TitleBlock v:
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (v.banner.isNotEmpty) ...[
            Text(v.banner, textAlign: TextAlign.center, style: ctr(base * .78, opacity: .72, spacing: base * .78 * .34)),
            SizedBox(height: base * 1.6),
          ],
          Text(v.title, textAlign: TextAlign.center, style: ctr(base * v.titleScale, weight: FontWeight.w600, spacing: base * v.titleScale * .02, height: 1.06)),
          if (v.byline.isNotEmpty) ...[
            SizedBox(height: base * 1.4),
            Text(v.byline, textAlign: TextAlign.center, style: ctr(base * .8, opacity: .78, spacing: base * .8 * .28)),
          ],
        ],
      );

    case DeptBlock v:
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v.header, textAlign: TextAlign.center, style: ctr(base * .78, opacity: .62, spacing: base * .78 * .26)),
          SizedBox(height: base * .55),
          for (final n in v.names)
            Padding(
              padding: EdgeInsets.only(bottom: base * .1),
              child: Text(n, textAlign: TextAlign.center, style: ctr(base, weight: FontWeight.w500, height: 1.42)),
            ),
        ],
      );

    case SongBlock v:
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v.songTitle, textAlign: TextAlign.center, style: ctr(base, weight: FontWeight.w500, height: 1.4)),
          Text(v.artist, textAlign: TextAlign.center, style: ctr(base * .86, opacity: .8, height: 1.4)),
          Text(v.courtesy, textAlign: TextAlign.center, style: ctr(base * .76, opacity: .6, height: 1.4).copyWith(fontStyle: FontStyle.italic)),
        ],
      );

    case LogosBlock v:
      return Wrap(
        alignment: WrapAlignment.center,
        spacing: base * 1.6,
        runSpacing: base * .6,
        children: [
          for (final l in v.logos)
            Container(
              padding: EdgeInsets.symmetric(horizontal: base * .6, vertical: base * .4),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white.withValues(alpha: .3)),
                borderRadius: BorderRadius.circular(base * .12),
              ),
              child: Text(l, style: ctr(base * .62, opacity: .82, spacing: base * .62 * .2)),
            ),
        ],
      );

    case ThanksBlock v:
      final columns = g.tall ? 2 : 3;
      final cols = _balanceColumns(v.names, columns);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v.header, textAlign: TextAlign.center, style: ctr(base * .78, opacity: .62, spacing: base * .78 * .26)),
          SizedBox(height: base * .8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < cols.length; i++) ...[
                if (i > 0) SizedBox(width: base * 1.4),
                Flexible(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final n in cols[i])
                        Padding(
                          padding: EdgeInsets.only(bottom: base * .2),
                          child: Text(n, textAlign: TextAlign.center, style: ctr(base * .84, opacity: .88, height: 1.5)),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ],
      );

    case CastBlock v:
      final cg = computeCastGeometry(v, g);
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v.header, textAlign: TextAlign.center, style: ctr(base * .78, opacity: .62, spacing: base * .78 * .26)),
          SizedBox(height: base * .9),
          for (final r in v.rows) _castRow(r, g, cg, v.leader, ctr),
        ],
      );
  }
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
