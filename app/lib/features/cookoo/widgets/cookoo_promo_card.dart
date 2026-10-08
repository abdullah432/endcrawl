import 'package:flutter/material.dart';

import '../../../core/theme/theme_context.dart';
import '../../../core/theme/tokens.dart';
import '../models/cookoo_content.dart';
import 'cookoo_style.dart';

/// One slide of the COOKOO studio card: 358 × 276, a fixed chassis (top
/// row, headline, footer, button) with the slide's own middle.
///
/// The card itself isn't tappable — only the button and the footer link.
class CookooPromoCard extends StatelessWidget {
  static const width = 358.0;
  static const height = 276.0;

  final CookooSlide slide;
  final VoidCallback onTellUs;

  /// Opens the slide's case study; ignored when the slide has none.
  final VoidCallback? onFooterTap;

  const CookooPromoCard({super.key, required this.slide, required this.onTellUs, this.onFooterTap});

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final app = slide.app;
    final result = slide.result;
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 14),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(EcRadius.hero),
        border: Border.all(color: p.line2),
      ),
      // The card's height is fixed so the pages line up; large text sizes
      // are capped here, and anything still too tall is clipped at the
      // bottom of the middle section rather than pushing the button out.
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _TopRow(),
            Expanded(
              child: SingleChildScrollView(
                physics: const NeverScrollableScrollPhysics(),
                primary: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (app != null) ...[
                      const SizedBox(height: 12),
                      _AppLine(app: app, category: slide.category ?? ''),
                    ],
                    const SizedBox(height: 10),
                    Text(slide.headline, style: context.cookooSerif(21), maxLines: 2, overflow: TextOverflow.ellipsis),
                    if (app == null) ...[const SizedBox(height: 12), const _TrackRecord()],
                    if (result != null) ...[const SizedBox(height: 10), _ResultBox(result)],
                    if (slide.tags.isNotEmpty) ...[const SizedBox(height: 10), _Tags(slide.tags)],
                  ],
                ),
              ),
            ),
            _Footer(text: slide.footer, onTap: slide.caseSlug == null ? null : onFooterTap),
            CookooInkButton(
              label: 'Tell us your idea',
              icon: Icons.arrow_forward,
              height: 42,
              fontSize: 20,
              iconSize: 17,
              onPressed: onTellUs,
            ),
          ],
        ),
      ),
    );
  }
}

class _TopRow extends StatelessWidget {
  const _TopRow();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: 14,
      child: Row(
        children: [
          Icon(Icons.egg, size: 14, color: p.ink),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'COOKOO · APP DESIGN & BUILD',
              style: context.cookooMono(10),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.fade,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
            decoration: BoxDecoration(
              border: Border.all(color: p.line2),
              borderRadius: BorderRadius.circular(5),
            ),
            child: Text('PAID SERVICE', style: context.cookooMono(9, tracking: 0.5, color: p.ink2)),
          ),
        ],
      ),
    );
  }
}

/// An app's icon: rounded, with a faint hairline so light icons hold an edge.
class _AppIcon extends StatelessWidget {
  final CookooApp app;
  final double size;
  const _AppIcon(this.app, {required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: context.palette.line),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(7),
        child: Image.asset(app.asset, width: size, height: size, fit: BoxFit.cover, excludeFromSemantics: true),
      ),
    );
  }
}

class _AppLine extends StatelessWidget {
  final CookooApp app;
  final String category;
  const _AppLine({required this.app, required this.category});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _AppIcon(app, size: 28),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(app.name, style: context.cookooUi(15, weight: FontWeight.w600, height: 1.1)),
              const SizedBox(height: 2),
              Text(category, style: context.cookooMono(10), maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ),
      ],
    );
  }
}

class _TrackRecord extends StatelessWidget {
  const _TrackRecord();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (final (i, (app, line)) in cookooTrackRecord.indexed) ...[
          if (i > 0) const SizedBox(height: 5),
          SizedBox(
            height: 26,
            child: Row(
              children: [
                _AppIcon(app, size: 26),
                const SizedBox(width: 10),
                Text(app.name, style: context.cookooUi(14, weight: FontWeight.w600)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    line,
                    style: context.cookooUi(13, color: context.palette.muted),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// The green result box — one of only two places green is used.
class _ResultBox extends StatelessWidget {
  final String text;
  const _ResultBox(this.text);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(color: p.okWash, borderRadius: BorderRadius.circular(EcRadius.inner)),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
            decoration: BoxDecoration(color: p.ok, borderRadius: BorderRadius.circular(5)),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.trending_up, size: 12, color: p.onInk),
                const SizedBox(width: 3),
                Text('RESULT', style: context.cookooMono(9, tracking: 1, color: p.onInk)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: context.cookooUi(13, weight: FontWeight.w600, height: 1.25, color: p.ok),
            ),
          ),
        ],
      ),
    );
  }
}

class _Tags extends StatelessWidget {
  final List<String> tags;
  const _Tags(this.tags);

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final tag in tags)
          Container(
            height: 26,
            // 9, not the design's 10: Archivo sets wider than Instrument Sans,
            // and this keeps HappyKosher's three tags on one line.
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(EcRadius.pill),
              border: Border.all(color: p.line2),
            ),
            // widthFactor 1: hug the label rather than fill the Wrap's width.
            child: Center(
              widthFactor: 1,
              child: Text(tag, style: context.cookooUi(12, weight: FontWeight.w600)),
            ),
          ),
      ],
    );
  }
}

/// The mono line above the button. When it links, its tap area runs the
/// card's width and takes in the gap above the button.
class _Footer extends StatelessWidget {
  final String text;
  final VoidCallback? onTap;
  const _Footer({required this.text, this.onTap});

  @override
  Widget build(BuildContext context) {
    final style = context.cookooMono(10);
    final line = Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Flexible(
            child: Text(text, style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
          ),
          if (onTap != null) ...[const SizedBox(width: 4), Icon(Icons.open_in_new, size: 12, color: style.color)],
        ],
      ),
    );
    if (onTap == null) return line;
    return Semantics(
      link: true,
      child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: line),
    );
  }
}
